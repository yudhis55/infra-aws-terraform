#!/usr/bin/env bash
set -euo pipefail

tf_dir="${1:-env/dev}"
expected_ecs="${2:?expected ECS desired count is required}"
expected_asg="${3:?expected ASG in-service count is required}"
minimum_wait_seconds="${4:-600}"
timeout_seconds="${5:-2400}"
out_file="${6:-experiment-evidence/runtime/baseline-readiness.json}"
interval_seconds="${BASELINE_POLL_INTERVAL_SECONDS:-60}"
stable_samples_required="${BASELINE_STABLE_SAMPLES:-2}"

for value in "$expected_ecs" "$expected_asg" "$minimum_wait_seconds" "$timeout_seconds" "$interval_seconds" "$stable_samples_required"; do
  [[ "$value" =~ ^[0-9]+$ ]] || { echo "baseline inputs must be non-negative integers" >&2; exit 2; }
done
[ "$expected_ecs" -ge 1 ] && [ "$expected_asg" -ge 1 ]
[ "$minimum_wait_seconds" -le "$timeout_seconds" ]
[ "$stable_samples_required" -ge 2 ]

cluster="$(terraform -chdir="$tf_dir" output -raw ecs_cluster_name)"
service="$(terraform -chdir="$tf_dir" output -raw ecs_service_name)"
asg="$(terraform -chdir="$tf_dir" output -raw asg_name)"
mkdir -p "$(dirname "$out_file")"
tmp="${out_file}.ndjson"
: > "$tmp"

started_epoch="$(date +%s)"
stable_samples=0
status=timeout
while true; do
  now_epoch="$(date +%s)"
  elapsed="$((now_epoch - started_epoch))"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  ecs="$(aws ecs describe-services --cluster "$cluster" --services "$service" --query 'services[0].{desired:desiredCount,running:runningCount,pending:pendingCount}' --output json)"
  # shellcheck disable=SC2016
  capacity="$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$asg" --query 'AutoScalingGroups[0].{desired:DesiredCapacity,inService:length(Instances[?LifecycleState==`InService`]),pending:length(Instances[?starts_with(LifecycleState, `Pending`)]),terminating:length(Instances[?starts_with(LifecycleState, `Terminating`)])}' --output json)"
  ready="$(jq -n --argjson ecs "$ecs" --argjson asg "$capacity" --argjson expectedEcs "$expected_ecs" --argjson expectedAsg "$expected_asg" --argjson elapsed "$elapsed" --argjson minimumWait "$minimum_wait_seconds" '$elapsed >= $minimumWait and $ecs.desired == $expectedEcs and $ecs.running == $expectedEcs and $ecs.pending == 0 and $asg.desired == $expectedAsg and $asg.inService == $expectedAsg and $asg.pending == 0 and $asg.terminating == 0')"
  jq -n --arg timestamp "$timestamp" --argjson elapsed "$elapsed" --argjson ecs "$ecs" --argjson asg "$capacity" --argjson ready "$ready" '{timestamp:$timestamp,elapsedSeconds:$elapsed,ecs:$ecs,asg:$asg,ready:$ready}' >> "$tmp"

  if [ "$ready" = true ]; then stable_samples="$((stable_samples + 1))"; else stable_samples=0; fi
  if [ "$stable_samples" -ge "$stable_samples_required" ]; then status=passed; break; fi
  if [ "$elapsed" -ge "$timeout_seconds" ]; then break; fi
  sleep "$interval_seconds"
done

jq -s --arg status "$status" --argjson expectedEcs "$expected_ecs" --argjson expectedAsg "$expected_asg" --argjson minimumWait "$minimum_wait_seconds" --argjson timeout "$timeout_seconds" --argjson stableSamples "$stable_samples_required" '{status:$status,expected:{ecsDesired:$expectedEcs,asgInService:$expectedAsg},minimumWaitSeconds:$minimumWait,timeoutSeconds:$timeout,stableSamplesRequired:$stableSamples,samples:.}' "$tmp" > "$out_file"
rm -f "$tmp"
jq -e '.status == "passed"' "$out_file" > /dev/null
