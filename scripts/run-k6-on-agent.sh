#!/usr/bin/env bash
set -euo pipefail

instance_id="${1:?instance ID is required}"
campaign_id="${2:?campaign ID is required}"
profile_file="${3:?locked profile JSON is required}"
load_script="${4:?k6 script is required}"
out_dir="${5:-experiment-evidence/runtime/k6-agent}"

jq -e '
  (.runType == "calibration" or .runType == "final-trial") and
  (.trialId | test("^(calibration|[1-3])$")) and
  (.stages | length) == 6 and
  all(.stages[]; (.targetVus >= 0 and .targetVus <= 30) and (.durationSeconds >= 1)) and
  ([.stages[].durationSeconds] | add) <= 2700
' "$profile_file" > /dev/null || { echo "load profile exceeds the approved envelope" >&2; exit 2; }

target_url="$(jq -r '.targetUrl' "$profile_file")"
[ "$target_url" = "https://eepistore.web.id" ] || { echo "load target is not allowlisted" >&2; exit 2; }
tag="$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=ExperimentId" --query 'Tags[0].Value' --output text)"
[ "$tag" = "$campaign_id" ] || { echo "agent campaign tag mismatch" >&2; exit 2; }

mkdir -p "$out_dir"
script_payload="$(base64 -w0 "$load_script")"
profile_payload="$(base64 -w0 "$profile_file")"
jq -n --arg script "$script_payload" --arg profile "$profile_payload" '{commands:[
  "set -euo pipefail",
  ("echo " + $script + " | base64 -d > /tmp/eepistore-load.js"),
  ("echo " + $profile + " | base64 -d > /tmp/eepistore-profile.json"),
  "export APP_URL=$(jq -r .targetUrl /tmp/eepistore-profile.json); export EXPERIMENT_ID=$(jq -r .campaignId /tmp/eepistore-profile.json); export TRIAL_ID=$(jq -r .trialId /tmp/eepistore-profile.json); export BASELINE_VUS=$(jq -r .stages[0].targetVus /tmp/eepistore-profile.json); export STEP_1_VUS=$(jq -r .stages[2].targetVus /tmp/eepistore-profile.json); export STEP_2_VUS=$(jq -r .stages[3].targetVus /tmp/eepistore-profile.json); export STEP_3_VUS=$(jq -r .stages[4].targetVus /tmp/eepistore-profile.json); export WARMUP_DURATION=$(jq -r '\''.stages[0].durationSeconds|tostring+\"s\"'\'' /tmp/eepistore-profile.json); export BASELINE_DURATION=$(jq -r '\''.stages[1].durationSeconds|tostring+\"s\"'\'' /tmp/eepistore-profile.json); export STEP_1_DURATION=$(jq -r '\''.stages[2].durationSeconds|tostring+\"s\"'\'' /tmp/eepistore-profile.json); export STEP_2_DURATION=$(jq -r '\''.stages[3].durationSeconds|tostring+\"s\"'\'' /tmp/eepistore-profile.json); export STEP_3_DURATION=$(jq -r '\''.stages[4].durationSeconds|tostring+\"s\"'\'' /tmp/eepistore-profile.json); export RECOVERY_DURATION=$(jq -r '\''.stages[5].durationSeconds|tostring+\"s\"'\'' /tmp/eepistore-profile.json)",
  "docker pull grafana/k6@sha256:e7eeddf1ce2361df6920d925297f487c0ba549c44be242c6a9c22f28d9b08efa >/dev/null",
  "if ! docker run --rm -e APP_URL -e EXPERIMENT_ID -e TRIAL_ID -e BASELINE_VUS -e STEP_1_VUS -e STEP_2_VUS -e STEP_3_VUS -e WARMUP_DURATION -e BASELINE_DURATION -e STEP_1_DURATION -e STEP_2_DURATION -e STEP_3_DURATION -e RECOVERY_DURATION -v /tmp:/scripts grafana/k6@sha256:e7eeddf1ce2361df6920d925297f487c0ba549c44be242c6a9c22f28d9b08efa run --summary-export /scripts/eepistore-k6-summary.json /scripts/eepistore-load.js > /tmp/eepistore-k6.log 2>&1; then tail -c 12000 /tmp/eepistore-k6.log >&2; exit 1; fi",
  "printf K6_SUMMARY_BASE64=; base64 -w0 /tmp/eepistore-k6-summary.json; printf :END"
]}' > "$out_dir/commands.json"

command_id="$(aws ssm send-command \
  --document-name AWS-RunShellScript \
  --instance-ids "$instance_id" \
  --timeout-seconds 3000 \
  --comment "k6-$campaign_id" \
  --parameters "file://$out_dir/commands.json" \
  --query 'Command.CommandId' --output text)"
for _ in $(seq 1 620); do
  status="$(aws ssm get-command-invocation --command-id "$command_id" --instance-id "$instance_id" --query Status --output text 2>/dev/null || true)"
  case "$status" in Success|Failed|TimedOut|Cancelled) break ;; esac
  sleep 5
done
aws ssm get-command-invocation --command-id "$command_id" --instance-id "$instance_id" > "$out_dir/invocation.json"
jq -e '.Status == "Success"' "$out_dir/invocation.json" > /dev/null
jq -r '.StandardOutputContent' "$out_dir/invocation.json" > "$out_dir/agent.log"
summary_frame="$(grep -o 'K6_SUMMARY_BASE64=[A-Za-z0-9+/=]*:END' "$out_dir/agent.log" | tail -1)"
[ -n "$summary_frame" ] || { echo "framed k6 summary was not returned by SSM" >&2; exit 1; }
summary_payload="${summary_frame#K6_SUMMARY_BASE64=}"
summary_payload="${summary_payload%:END}"
printf '%s' "$summary_payload" | base64 -d > "$out_dir/summary.json"
jq -e '.metrics.http_req_failed != null and .metrics.http_req_duration != null' "$out_dir/summary.json" > /dev/null
