#!/usr/bin/env bash
set -euo pipefail

instance_id="${1:?instance ID is required}"
campaign_id="${2:?campaign ID is required}"
out_dir="${3:-experiment-evidence/agent-readiness}"

[[ "$campaign_id" =~ ^campaign-[0-9]{8}-[0-9a-f]{7}-[0-9a-f]{7}$ ]] || {
  echo "invalid campaign ID" >&2
  exit 2
}

tag="$(aws ec2 describe-tags \
  --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=ExperimentId" \
  --query 'Tags[0].Value' --output text)"
[ "$tag" = "$campaign_id" ] || { echo "agent campaign tag mismatch" >&2; exit 2; }

mkdir -p "$out_dir"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
started_epoch="$(date +%s)"
ping_status=""
for _ in $(seq 1 60); do
  ping_status="$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$instance_id" \
    --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || true)"
  [ "$ping_status" = Online ] && break
  sleep 10
done
[ "$ping_status" = Online ] || { echo "agent did not become SSM Online within 600 seconds" >&2; exit 3; }

# shellcheck disable=SC2016 # Command substitution is intentionally deferred to the SSM target.
command_id="$(aws ssm send-command \
  --document-name AWS-RunShellScript \
  --instance-ids "$instance_id" \
  --timeout-seconds 360 \
  --comment "readiness-$campaign_id" \
  --parameters 'commands=["set -euo pipefail","for attempt in $(seq 1 60); do if test -f /var/lib/eepistore-experiment/ready && docker info >/dev/null 2>&1; then exit 0; fi; sleep 5; done","echo bootstrap readiness failed >&2","tail -n 200 /var/log/eepistore-experiment-bootstrap.log /var/log/cloud-init-output.log >&2 || true","exit 1"]' \
  --query 'Command.CommandId' --output text)"

for _ in $(seq 1 78); do
  command_status="$(aws ssm get-command-invocation \
    --command-id "$command_id" --instance-id "$instance_id" \
    --query Status --output text 2>/dev/null || true)"
  case "$command_status" in Success|Failed|TimedOut|Cancelled) break ;; esac
  sleep 5
done
aws ssm get-command-invocation --command-id "$command_id" --instance-id "$instance_id" > "$out_dir/docker-readiness-invocation.json"
jq -e '.Status == "Success"' "$out_dir/docker-readiness-invocation.json" > /dev/null

ended_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ended_epoch="$(date +%s)"
jq -n \
  --arg instanceId "$instance_id" \
  --arg campaignId "$campaign_id" \
  --arg startedAt "$started_at" \
  --arg endedAt "$ended_at" \
  --argjson durationSeconds "$((ended_epoch - started_epoch))" \
  '{status:"passed",instanceId:$instanceId,campaignId:$campaignId,ssmPingStatus:"Online",dockerReady:true,startedAt:$startedAt,endedAt:$endedAt,durationSeconds:$durationSeconds}' \
  > "$out_dir/readiness.json"
