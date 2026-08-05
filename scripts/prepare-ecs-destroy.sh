#!/usr/bin/env bash
set -euo pipefail

tf_dir="${1:-env/dev}"
out_dir="${2:-destroy-evidence/preparation}"
poll_interval="${ECS_DRAIN_POLL_INTERVAL_SECONDS:-15}"
max_attempts="${ECS_DRAIN_MAX_ATTEMPTS:-60}"
mkdir -p "$out_dir"

cluster="$(terraform -chdir="$tf_dir" output -raw ecs_cluster_name 2>/dev/null || true)"
service="$(terraform -chdir="$tf_dir" output -raw ecs_service_name 2>/dev/null || true)"
target_group="$(terraform -chdir="$tf_dir" output -raw target_group_arn 2>/dev/null || true)"
alb_arn="$(terraform -chdir="$tf_dir" output -raw alb_arn 2>/dev/null || true)"
resource_id="service/$cluster/$service"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
started_epoch="$(date +%s)"
status="failed"
service_drained=false
targets_drained=false
access_logging_disabled=false

write_result() {
  local ended_at
  local ended_epoch
  ended_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  ended_epoch="$(date +%s)"
  jq -n \
    --arg status "$status" \
    --arg cluster "$cluster" \
    --arg service "$service" \
    --arg targetGroup "$target_group" \
    --arg albArn "$alb_arn" \
    --arg startedAt "$started_at" \
    --arg endedAt "$ended_at" \
    --argjson durationSeconds "$((ended_epoch - started_epoch))" \
    --argjson serviceDrained "$service_drained" \
    --argjson targetsDrained "$targets_drained" \
    --argjson accessLoggingDisabled "$access_logging_disabled" \
    '{status:$status,cluster:$cluster,service:$service,targetGroup:$targetGroup,albArn:$albArn,startedAt:$startedAt,endedAt:$endedAt,durationSeconds:$durationSeconds,serviceDrained:$serviceDrained,targetsDrained:$targetsDrained,accessLoggingDisabled:$accessLoggingDisabled}' \
    > "$out_dir/result.json"
}
trap write_result EXIT

if [ -n "$alb_arn" ]; then
  aws elbv2 modify-load-balancer-attributes \
    --load-balancer-arn "$alb_arn" \
    --attributes Key=access_logs.s3.enabled,Value=false \
    > "$out_dir/alb-access-logging-disabled.json"
  access_logging_disabled=true
fi

if [ -z "$cluster" ] || [ -z "$service" ] || [ -z "$target_group" ]; then
  status="not-found"
  exit 0
fi

aws ecs describe-services --cluster "$cluster" --services "$service" \
  > "$out_dir/service-before.json"
service_status="$(jq -r '.services[0].status // "NOT_FOUND"' "$out_dir/service-before.json")"

if [ "$service_status" != "ACTIVE" ]; then
  status="not-found"
  exit 0
fi

# Stop target-tracking policies from restoring desired count while the service drains.
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id "$resource_id" \
  --scalable-dimension ecs:service:DesiredCount \
  --suspended-state DynamicScalingInSuspended=true,ScheduledScalingSuspended=true,DynamicScalingOutSuspended=true \
  > "$out_dir/autoscaling-suspended.json"

aws ecs update-service --cluster "$cluster" --service "$service" --desired-count 0 \
  > "$out_dir/service-scale-down.json"

for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  aws ecs describe-services --cluster "$cluster" --services "$service" \
    > "$out_dir/service-current.json"
  if jq -e '
    .services[0] as $service |
    $service.desiredCount == 0 and
    $service.runningCount == 0 and
    $service.pendingCount == 0
  ' "$out_dir/service-current.json" > /dev/null; then
    service_drained=true
    break
  fi
  if [ "$attempt" -lt "$max_attempts" ]; then sleep "$poll_interval"; fi
done

if [ "$service_drained" != true ]; then
  echo "ECS service did not drain to zero before Terraform destroy" >&2
  exit 1
fi

for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  aws elbv2 describe-target-health --target-group-arn "$target_group" \
    > "$out_dir/target-health-current.json"
  if jq -e '.TargetHealthDescriptions | length == 0' \
    "$out_dir/target-health-current.json" > /dev/null; then
    targets_drained=true
    break
  fi
  if [ "$attempt" -lt "$max_attempts" ]; then sleep "$poll_interval"; fi
done

if [ "$targets_drained" != true ]; then
  echo "ALB targets did not deregister before Terraform destroy" >&2
  exit 1
fi

status="passed"
