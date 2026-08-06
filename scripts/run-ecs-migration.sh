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
log_group="$(terraform -chdir="$tf_dir" output -raw ecs_log_group_name)"
proxy="$(terraform -chdir="$tf_dir" output -raw rds_proxy_id)"
task_definition="$(aws ecs describe-services \
  --cluster "$cluster" --services "$service" \
  --query 'services[0].taskDefinition' --output text)"

proxy_poll_interval="${MIGRATION_PROXY_POLL_INTERVAL_SECONDS:-15}"
proxy_max_attempts="${MIGRATION_PROXY_MAX_ATTEMPTS:-60}"
proxy_ready=false
proxy_wait_started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
proxy_wait_started_epoch="$(date +%s)"

for ((attempt = 1; attempt <= proxy_max_attempts; attempt++)); do
  if aws rds describe-db-proxy-targets \
    --db-proxy-name "$proxy" > "$out_dir/proxy-targets.json" 2> "$out_dir/proxy-targets-error.txt" && \
    jq -e '.Targets | length > 0 and all(.TargetHealth.State == "AVAILABLE")' \
      "$out_dir/proxy-targets.json" > /dev/null; then
    proxy_ready=true
    rm -f "$out_dir/proxy-targets-error.txt"
    break
  fi
  if [ "$attempt" -lt "$proxy_max_attempts" ]; then sleep "$proxy_poll_interval"; fi
done

proxy_wait_ended="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
proxy_wait_ended_epoch="$(date +%s)"
proxy_status="failed"
if [ "$proxy_ready" = true ]; then proxy_status="passed"; fi
jq -n \
  --arg status "$proxy_status" \
  --arg proxy "$proxy" \
  --arg startedAt "$proxy_wait_started" \
  --arg endedAt "$proxy_wait_ended" \
  --argjson durationSeconds "$((proxy_wait_ended_epoch - proxy_wait_started_epoch))" \
  '{status:$status,proxy:$proxy,startedAt:$startedAt,endedAt:$endedAt,durationSeconds:$durationSeconds}' \
  > "$out_dir/proxy-readiness.json"

if [ "$proxy_ready" != true ]; then
  echo "RDS Proxy target did not become AVAILABLE before migration" >&2
  exit 1
fi

migration_max_attempts="${MIGRATION_TASK_MAX_ATTEMPTS:-3}"
migration_retry_delay="${MIGRATION_TASK_RETRY_DELAY_SECONDS:-30}"
attempt_records="$out_dir/attempts.ndjson"
: > "$attempt_records"

for ((migration_attempt = 1; migration_attempt <= migration_max_attempts; migration_attempt++)); do
  attempt_dir="$out_dir/attempt-${migration_attempt}"
  mkdir -p "$attempt_dir"
  attempt_started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  task_arn="$(aws ecs run-task \
    --cluster "$cluster" \
    --task-definition "$task_definition" \
    --count 1 \
    --started-by "terraform-${GITHUB_RUN_ID:-local}-migration-${migration_attempt}" \
    --overrides '{"containerOverrides":[{"name":"app","command":["node","node_modules/prisma/build/index.js","migrate","deploy"]}]}' \
    --query 'tasks[0].taskArn' --output text)"

  if [ -z "$task_arn" ] || [ "$task_arn" = "None" ]; then
    echo "ECS did not start migration task attempt $migration_attempt" >&2
    exit 1
  fi

  aws ecs wait tasks-stopped --cluster "$cluster" --tasks "$task_arn"
  aws ecs describe-tasks --cluster "$cluster" --tasks "$task_arn" > "$attempt_dir/task.json"

  task_id="${task_arn##*/}"
  stream_name="ecs/app/${task_id}"
  for log_attempt in 1 2 3 4 5; do
    if aws logs get-log-events \
      --log-group-name "$log_group" \
      --log-stream-name "$stream_name" \
      --start-from-head > "$attempt_dir/logs.json" 2> "$attempt_dir/logs-error.txt"; then
      rm -f "$attempt_dir/logs-error.txt"
      break
    fi
    sleep "$log_attempt"
  done

  if [ ! -s "$attempt_dir/logs.json" ]; then
    echo "Unable to collect migration logs from $stream_name" >&2
  fi

  cp "$attempt_dir/task.json" "$out_dir/task.json"
  if [ -s "$attempt_dir/logs.json" ]; then cp "$attempt_dir/logs.json" "$out_dir/logs.json"; fi

  exit_code="$(jq -r '.tasks[0].containers[] | select(.name == "app") | .exitCode // empty' \
    "$attempt_dir/task.json")"
  retryable=false
  if [ "$exit_code" != "0" ] && [ -s "$attempt_dir/logs.json" ] && \
    jq -e '[.events[]?.message] | any(test("P1001"))' "$attempt_dir/logs.json" > /dev/null; then
    retryable=true
  fi

  attempt_status="failed"
  if [ "$exit_code" = "0" ]; then
    attempt_status="passed"
  elif [ "$retryable" = true ]; then
    attempt_status="retryable-failure"
  fi
  jq -n \
    --argjson attempt "$migration_attempt" \
    --arg status "$attempt_status" \
    --arg taskArn "$task_arn" \
    --arg exitCode "${exit_code:-missing}" \
    --arg startedAt "$attempt_started_at" \
    '{attempt:$attempt,status:$status,taskArn:$taskArn,exitCode:$exitCode,startedAt:$startedAt}' \
    >> "$attempt_records"

  if [ "$exit_code" = "0" ]; then
    jq -s '.' "$attempt_records" > "$out_dir/attempts.json"
    rm -f "$attempt_records"
    printf 'PASS migration\n%s\n' "$task_arn" > "$out_dir/status.txt"
    exit 0
  fi

  if [ "$retryable" = true ] && [ "$migration_attempt" -lt "$migration_max_attempts" ]; then
    echo "Migration attempt $migration_attempt hit Prisma P1001; retrying after ${migration_retry_delay}s" >&2
    sleep "$migration_retry_delay"
    continue
  fi

  jq -s '.' "$attempt_records" > "$out_dir/attempts.json"
  rm -f "$attempt_records"
  echo "Migration failed with exit code ${exit_code:-missing}; retryable=$retryable" >&2
  exit 1
done
