#!/usr/bin/env bash
set -euo pipefail

instance_id="${1:?instance ID is required}"
campaign_id="${2:?campaign ID is required}"
target_url="${3:?target URL is required}"
out_dir="${4:-experiment-evidence/security/waf-rate}"

expected_url="https://eepistore.web.id/api/experiment/rate-limit"
[ "$target_url" = "$expected_url" ] || { echo "target must be $expected_url" >&2; exit 2; }
[[ "$campaign_id" =~ ^campaign-[0-9]{8}-[0-9a-f]{7}-[0-9a-f]{7}$ ]] || { echo "invalid campaign ID" >&2; exit 2; }

tag="$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=ExperimentId" --query 'Tags[0].Value' --output text)"
[ "$tag" = "$campaign_id" ] || { echo "agent campaign tag mismatch" >&2; exit 2; }

mkdir -p "$out_dir"
cat > "$out_dir/commands.json" <<'JSON'
{
  "commands": [
    "set -euo pipefail",
    "url='https://eepistore.web.id/api/experiment/rate-limit'",
    "start_epoch=$(date +%s); start_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ); total=0; blocked=0; first_block_at=null; status=0",
    "while [ $total -lt 150 ] && [ $(( $(date +%s) - start_epoch )) -lt 120 ]; do now=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ); status=$(curl --silent --show-error --max-time 10 --output /dev/null --write-out '%{http_code}' \"$url\"); total=$((total+1)); printf '{\"timestamp\":\"%s\",\"sequence\":%d,\"status\":%s}\\n' \"$now\" \"$total\" \"$status\"; if [ \"$status\" = 429 ]; then blocked=$((blocked+1)); first_block_at=\"$now\"; break; fi; if [ \"$status\" -ge 500 ]; then exit 50; fi; sleep 0.5; done",
    "end_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ); printf 'WAF_RATE_SUMMARY={\"startedAt\":\"%s\",\"endedAt\":\"%s\",\"totalRequests\":%d,\"blockedRequests\":%d,\"firstBlockAt\":\"%s\",\"maxRequests\":150,\"maxRateRps\":2,\"maxDurationSeconds\":120}\\n' \"$start_at\" \"$end_at\" \"$total\" \"$blocked\" \"$first_block_at\"",
    "test $total -le 150; test $blocked -eq 1"
  ]
}
JSON

command_id="$(aws ssm send-command \
  --document-name AWS-RunShellScript \
  --instance-ids "$instance_id" \
  --timeout-seconds 180 \
  --comment "bounded-rate-$campaign_id" \
  --parameters "file://$out_dir/commands.json" \
  --query 'Command.CommandId' --output text)"

for _ in $(seq 1 48); do
  status="$(aws ssm get-command-invocation --command-id "$command_id" --instance-id "$instance_id" --query Status --output text 2>/dev/null || true)"
  case "$status" in Success|Failed|TimedOut|Cancelled) break ;; esac
  sleep 5
done
aws ssm get-command-invocation --command-id "$command_id" --instance-id "$instance_id" > "$out_dir/invocation.json"
jq -e '.Status == "Success"' "$out_dir/invocation.json" > /dev/null
jq -r '.StandardOutputContent' "$out_dir/invocation.json" > "$out_dir/generator.log"
summary="$(grep '^WAF_RATE_SUMMARY=' "$out_dir/generator.log" | tail -1 | cut -d= -f2-)"
jq -e '.totalRequests <= 150 and .maxRateRps == 2 and .maxDurationSeconds == 120 and .blockedRequests == 1' \
  <<< "$summary" > "$out_dir/generator-summary.json"
