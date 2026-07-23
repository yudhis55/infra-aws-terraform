#!/usr/bin/env bash
set -euo pipefail

tf_dir="${1:-env/dev}"
action="${2:?fixture action setup or cleanup is required}"
out_dir="${3:-experiment-evidence}"

case "$action" in
  setup|cleanup) ;;
  *) echo "Unsupported fixture action: $action" >&2; exit 2 ;;
esac

for name in EXPERIMENT_ID EXPERIMENT_BUYER_EMAIL EXPERIMENT_OTHER_BUYER_EMAIL \
  EXPERIMENT_SELLER_EMAIL EXPERIMENT_ADMIN_EMAIL; do
  test -n "${!name:-}" || { echo "$name is required" >&2; exit 2; }
done

mkdir -p "$out_dir"
cluster="$(terraform -chdir="$tf_dir" output -raw ecs_cluster_name)"
service="$(terraform -chdir="$tf_dir" output -raw ecs_service_name)"
log_group="$(terraform -chdir="$tf_dir" output -raw ecs_log_group_name)"
task_definition="$(aws ecs describe-services \
  --cluster "$cluster" --services "$service" \
  --query 'services[0].taskDefinition' --output text)"

overrides="$(jq -cn \
  --arg action "$action" \
  --arg experiment_id "$EXPERIMENT_ID" \
  --arg buyer "$EXPERIMENT_BUYER_EMAIL" \
  --arg other "$EXPERIMENT_OTHER_BUYER_EMAIL" \
  --arg seller "$EXPERIMENT_SELLER_EMAIL" \
  --arg admin "$EXPERIMENT_ADMIN_EMAIL" \
  '{
    containerOverrides: [{
      name: "app",
      command: [
        "node",
        "--disable-warning=MODULE_TYPELESS_PACKAGE_JSON",
        "--experimental-strip-types",
        "scripts/experiment-fixtures.mts",
        $action
      ],
      environment: [
        {name: "EXPERIMENT_ID", value: $experiment_id},
        {name: "EXPERIMENT_BUYER_EMAIL", value: $buyer},
        {name: "EXPERIMENT_OTHER_BUYER_EMAIL", value: $other},
        {name: "EXPERIMENT_SELLER_EMAIL", value: $seller},
        {name: "EXPERIMENT_ADMIN_EMAIL", value: $admin}
      ]
    }]
  }')"

started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
task_arn="$(aws ecs run-task \
  --cluster "$cluster" \
  --task-definition "$task_definition" \
  --count 1 \
  --started-by "experiment-${GITHUB_RUN_ID:-local}-${action}" \
  --overrides "$overrides" \
  --query 'tasks[0].taskArn' --output text)"

if [ -z "$task_arn" ] || [ "$task_arn" = "None" ]; then
  echo "ECS did not start the fixture task" >&2
  exit 1
fi

aws ecs wait tasks-stopped --cluster "$cluster" --tasks "$task_arn"
aws ecs describe-tasks --cluster "$cluster" --tasks "$task_arn" > "$out_dir/${action}-task.json"
exit_code="$(jq -r '.tasks[0].containers[] | select(.name == "app") | .exitCode // empty' \
  "$out_dir/${action}-task.json")"
if [ "$exit_code" != "0" ]; then
  echo "Fixture $action failed with exit code ${exit_code:-missing}" >&2
  exit 1
fi

task_id="${task_arn##*/}"
stream_name="ecs/app/${task_id}"
aws logs get-log-events \
  --log-group-name "$log_group" \
  --log-stream-name "$stream_name" \
  --start-from-head > "$out_dir/${action}-logs.json"

marker="EXPERIMENT_FIXTURE_JSON="
output_file="$out_dir/fixture.json"
if [ "$action" = "cleanup" ]; then
  marker="EXPERIMENT_CLEANUP_JSON="
  output_file="$out_dir/cleanup.json"
fi
jq -r --arg marker "$marker" \
  '[.events[].message | select(contains($marker)) | split($marker)[1]] | last // empty' \
  "$out_dir/${action}-logs.json" > "$output_file"
jq -e --arg id "$EXPERIMENT_ID" '.experimentId == $id' "$output_file" > /dev/null

ended_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
jq -n \
  --arg action "$action" \
  --arg task_arn "$task_arn" \
  --arg started_at "$started_at" \
  --arg ended_at "$ended_at" \
  '{action: $action, taskArn: $task_arn, startedAt: $started_at, endedAt: $ended_at, status: "passed"}' \
  > "$out_dir/${action}-timing.json"
