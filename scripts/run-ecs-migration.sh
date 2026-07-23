#!/usr/bin/env bash
set -euo pipefail

tf_dir="${1:-env/dev}"
out_dir="${2:-migration-evidence}"
mkdir -p "$out_dir"
mkdir -p "$out_dir/timing"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
started_epoch="$(date +%s)"

write_timing() {
  local exit_code="$?"
  local ended_at
  local ended_epoch
  local status="passed"
  ended_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  ended_epoch="$(date +%s)"
  if [ "$exit_code" -ne 0 ]; then status="failed"; fi
  jq -n \
    --arg status "$status" \
    --arg startedAt "$started_at" \
    --arg endedAt "$ended_at" \
    --argjson durationSeconds "$((ended_epoch - started_epoch))" \
    '{status:$status, startedAt:$startedAt, endedAt:$endedAt, durationSeconds:$durationSeconds}' \
    > "$out_dir/timing/migration-timing.json"
}
trap write_timing EXIT

cluster="$(terraform -chdir="$tf_dir" output -raw ecs_cluster_name)"
service="$(terraform -chdir="$tf_dir" output -raw ecs_service_name)"
task_definition="$(aws ecs describe-services \
  --cluster "$cluster" --services "$service" \
  --query 'services[0].taskDefinition' --output text)"

task_arn="$(aws ecs run-task \
  --cluster "$cluster" \
  --task-definition "$task_definition" \
  --count 1 \
  --started-by "terraform-${GITHUB_RUN_ID:-local}-migration" \
  --overrides '{"containerOverrides":[{"name":"app","command":["node","node_modules/prisma/build/index.js","migrate","deploy"]}]}' \
  --query 'tasks[0].taskArn' --output text)"

if [ -z "$task_arn" ] || [ "$task_arn" = "None" ]; then
  echo "ECS did not start the migration task" >&2
  exit 1
fi

aws ecs wait tasks-stopped --cluster "$cluster" --tasks "$task_arn"
aws ecs describe-tasks --cluster "$cluster" --tasks "$task_arn" > "$out_dir/task.json"

exit_code="$(jq -r '.tasks[0].containers[] | select(.name == "app") | .exitCode // empty' \
  "$out_dir/task.json")"
if [ "$exit_code" != "0" ]; then
  echo "Migration failed with exit code ${exit_code:-missing}" >&2
  exit 1
fi

printf 'PASS migration\n%s\n' "$task_arn" > "$out_dir/status.txt"
