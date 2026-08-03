#!/usr/bin/env bash
set -euo pipefail

tf_dir="${1:-env/dev}"
duration_seconds="${2:-2700}"
out_file="${3:-experiment-evidence/runtime/scaling-events.json}"
interval_seconds="${4:-60}"

if ! [[ "$duration_seconds" =~ ^[0-9]+$ ]] || [ "$duration_seconds" -lt 60 ] || [ "$duration_seconds" -gt 2700 ]; then
  echo "duration must be between 60 and 2700 seconds" >&2
  exit 2
fi
if [ "$interval_seconds" != "60" ]; then
  echo "final evidence uses a fixed 60-second collection grain" >&2
  exit 2
fi

cluster="$(terraform -chdir="$tf_dir" output -raw ecs_cluster_name)"
service="$(terraform -chdir="$tf_dir" output -raw ecs_service_name)"
asg="$(terraform -chdir="$tf_dir" output -raw asg_name)"
mkdir -p "$(dirname "$out_file")"
tmp="${out_file}.ndjson"
: > "$tmp"

started_epoch="$(date +%s)"
while [ "$(( $(date +%s) - started_epoch ))" -le "$duration_seconds" ]; do
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  ecs="$(aws ecs describe-services --cluster "$cluster" --services "$service" --query 'services[0].{desired:desiredCount,running:runningCount,pending:pendingCount}' --output json)"
  capacity="$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$asg" --query 'AutoScalingGroups[0].{desired:DesiredCapacity,inService:length(Instances[?LifecycleState==`InService`]),pending:length(Instances[?starts_with(LifecycleState, `Pending`)]),terminating:length(Instances[?starts_with(LifecycleState, `Terminating`)])}' --output json)"
  jq -n --arg timestamp "$timestamp" --argjson ecs "$ecs" --argjson asg "$capacity" \
    '{timestamp:$timestamp, ecs:$ecs, asg:$asg}' >> "$tmp"
  sleep "$interval_seconds"
done

aws application-autoscaling describe-scaling-activities \
  --service-namespace ecs --resource-id "service/$cluster/$service" --max-results 50 \
  > "${out_file}.ecs-activities"
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name "$asg" --max-records 100 \
  > "${out_file}.asg-activities"

jq -s \
  --slurpfile ecs "${out_file}.ecs-activities" \
  --slurpfile asg "${out_file}.asg-activities" \
  '{samples:., ecsActivities:$ecs[0].ScalingActivities, asgActivities:$asg[0].Activities}' \
  "$tmp" > "$out_file"
rm -f "$tmp" "${out_file}.ecs-activities" "${out_file}.asg-activities"
