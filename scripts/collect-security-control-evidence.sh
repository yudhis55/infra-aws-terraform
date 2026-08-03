#!/usr/bin/env bash
set -euo pipefail

tf_dir="${1:-env/dev}"
start_time="${2:?start time is required}"
end_time="${3:?end time is required}"
agent_ip="${4:?agent private IP is required}"
out_dir="${5:-experiment-evidence/security/control-correlation}"
collection_mode="${6:-all}"

[[ "$agent_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "invalid agent IPv4" >&2; exit 2; }
mkdir -p "$out_dir"
flow_log_group="$(terraform -chdir="$tf_dir" output -raw vpc_flow_log_group_name)"
waf_arn="$(terraform -chdir="$tf_dir" output -raw waf_web_acl_arn)"

start_epoch="$(date -d "$start_time" +%s)"
end_epoch="$(date -d "$end_time" +%s)"
query="fields @timestamp, @message | parse @message '* * * * * * * * * * * * * *' as version, accountId, interfaceId, srcAddr, dstAddr, srcPort, dstPort, protocol, packets, bytes, start, end, action, logStatus | filter srcAddr = '$agent_ip' | sort @timestamp asc | limit 1000"
query_id="$(aws logs start-query \
  --log-group-name "$flow_log_group" \
  --start-time "$start_epoch" \
  --end-time "$end_epoch" \
  --query-string "$query" \
  --query queryId --output text)"
for _ in $(seq 1 90); do
  status="$(aws logs get-query-results --query-id "$query_id" --query status --output text)"
  case "$status" in Complete|Failed|Cancelled|Timeout|Unknown) break ;; esac
  sleep 10
done
aws logs get-query-results --query-id "$query_id" > "$out_dir/flow-log-evidence.json"
jq -e '.status == "Complete"' "$out_dir/flow-log-evidence.json" > /dev/null

if [ "$collection_mode" != "network-only" ] && [ -n "$waf_arn" ] && [ "$waf_arn" != "null" ]; then
  aws wafv2 get-sampled-requests \
    --web-acl-arn "$waf_arn" \
    --rule-metric-name ExperimentRateLimitMetric \
    --scope REGIONAL \
    --time-window "StartTime=$start_time,EndTime=$end_time" \
    --max-items 100 > "$out_dir/waf-sampled-requests.json"
fi

jq -n \
  --arg startTime "$start_time" \
  --arg endTime "$end_time" \
  --arg agentPrivateIp "$agent_ip" \
  --arg flowLogGroup "$flow_log_group" \
  '{status:"collected",startTime:$startTime,endTime:$endTime,agentPrivateIp:$agentPrivateIp,flowLogGroup:$flowLogGroup}' \
  > "$out_dir/collection-window.json"
