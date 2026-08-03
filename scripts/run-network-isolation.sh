#!/usr/bin/env bash
set -euo pipefail

instance_id="${1:?instance ID is required}"
campaign_id="${2:?campaign ID is required}"
targets_file="${3:?reviewed targets JSON is required}"
out_dir="${4:-experiment-evidence/security/network}"

jq -e '
  (.targets | length) > 0 and
  all(.targets[];
    (.host | test("^[A-Za-z0-9.-]+$")) and
    (.host | contains("/") | not) and
    ((.port == 443) or (.port == 5432) or (.port >= 32768 and .port <= 65535)) and
    (.attempts == 1 or .attempts == 3) and
    (.control == "vpc-network" or .control == "positive-network" or .control == "storage-policy")
  )
' "$targets_file" > /dev/null || { echo "target allowlist is invalid" >&2; exit 2; }

tag="$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=ExperimentId" --query 'Tags[0].Value' --output text)"
[ "$tag" = "$campaign_id" ] || { echo "agent campaign tag mismatch" >&2; exit 2; }

mkdir -p "$out_dir"
payload="$(base64 -w0 "$targets_file")"
jq -n --arg payload "$payload" '{commands:[
  "set -euo pipefail",
  ("echo " + $payload + " | base64 -d > /tmp/network-targets.json"),
  "jq -c '\''.targets[]'\'' /tmp/network-targets.json | while read -r target; do id=$(jq -r .id <<<\"$target\"); host=$(jq -r .host <<<\"$target\"); port=$(jq -r .port <<<\"$target\"); attempts=$(jq -r .attempts <<<\"$target\"); control=$(jq -r .control <<<\"$target\"); expected=$(jq -r .expected <<<\"$target\"); destination_ip=$(getent ahostsv4 \"$host\" | awk '\''NR==1 {print $1}'\''); for sequence in $(seq 1 \"$attempts\"); do at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ); if [ \"$control\" = storage-policy ]; then code=$(curl --silent --show-error --max-time 10 --output /dev/null --write-out '\''%{http_code}'\'' \"https://$host\"); actual=\"http-$code\"; else if timeout 10 bash -c \"</dev/tcp/$host/$port\" 2>/dev/null; then actual=success; else actual=denied; fi; fi; printf '\''{\"id\":\"%s\",\"host\":\"%s\",\"destinationIp\":\"%s\",\"port\":%d,\"sequence\":%d,\"timestamp\":\"%s\",\"control\":\"%s\",\"expected\":\"%s\",\"actual\":\"%s\"}\\n'\'' \"$id\" \"$host\" \"$destination_ip\" \"$port\" \"$sequence\" \"$at\" \"$control\" \"$expected\" \"$actual\"; [ \"$actual\" = \"$expected\" ] || exit 51; if [ \"$sequence\" -lt \"$attempts\" ]; then sleep 10; fi; done; done"
]}' > "$out_dir/commands.json"

command_id="$(aws ssm send-command \
  --document-name AWS-RunShellScript \
  --instance-ids "$instance_id" \
  --timeout-seconds 300 \
  --comment "network-$campaign_id" \
  --parameters "file://$out_dir/commands.json" \
  --query 'Command.CommandId' --output text)"
for _ in $(seq 1 72); do
  status="$(aws ssm get-command-invocation --command-id "$command_id" --instance-id "$instance_id" --query Status --output text 2>/dev/null || true)"
  case "$status" in Success|Failed|TimedOut|Cancelled) break ;; esac
  sleep 5
done
aws ssm get-command-invocation --command-id "$command_id" --instance-id "$instance_id" > "$out_dir/invocation.json"
jq -e '.Status == "Success"' "$out_dir/invocation.json" > /dev/null
jq -r '.StandardOutputContent' "$out_dir/invocation.json" | jq -s '{attempts:.}' > "$out_dir/network-isolation.json"
