#!/usr/bin/env bash
set -euo pipefail

test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/evidence"

cat > "$test_root/bin/terraform" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${!#}" in
  ecs_cluster_name) echo eepistore-cluster ;;
  ecs_service_name) echo eepistore-service ;;
  ecs_log_group_name) echo /ecs/eepistore ;;
  rds_proxy_id) echo eepistore-dev-proxy ;;
  *) exit 2 ;;
esac
EOF

cat > "$test_root/bin/aws" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_AWS_CALLS"
case "$1 $2" in
  "rds describe-db-proxy-targets")
    attempts=0
    if [ -f "$MOCK_PROXY_ATTEMPTS" ]; then attempts="$(cat "$MOCK_PROXY_ATTEMPTS")"; fi
    attempts=$((attempts + 1))
    echo "$attempts" > "$MOCK_PROXY_ATTEMPTS"
    if [ "$attempts" -eq 1 ]; then
      printf '%s\n' '{"Targets":[{"TargetHealth":{"State":"REGISTERING"}}]}'
    else
      printf '%s\n' '{"Targets":[{"TargetHealth":{"State":"AVAILABLE"}}]}'
    fi
    ;;
  "ecs describe-services") printf '%s\n' 'arn:aws:ecs:test:task-definition/eepistore-task:1' ;;
  "ecs run-task") printf '%s\n' 'arn:aws:ecs:test:task/eepistore-cluster/task-123' ;;
  "ecs wait") ;;
  "ecs describe-tasks")
    task_attempts=0
    if [ -f "$MOCK_TASK_ATTEMPTS" ]; then task_attempts="$(cat "$MOCK_TASK_ATTEMPTS")"; fi
    task_attempts=$((task_attempts + 1))
    echo "$task_attempts" > "$MOCK_TASK_ATTEMPTS"
    if { [ "${MOCK_TRANSIENT_P1001:-false}" = true ] && [ "$task_attempts" -eq 1 ]; } || \
      [ "${MOCK_NONRETRYABLE_FAILURE:-false}" = true ]; then
      printf '%s\n' '{"tasks":[{"containers":[{"name":"app","exitCode":1}]}],"failures":[]}'
    else
      printf '%s\n' '{"tasks":[{"containers":[{"name":"app","exitCode":0}]}],"failures":[]}'
    fi
    ;;
  "logs get-log-events")
    if [ "${MOCK_NONRETRYABLE_FAILURE:-false}" = true ]; then
      printf '%s\n' '{"events":[{"message":"Error: P1000: Authentication failed"}]}'
    elif [ "${MOCK_TRANSIENT_P1001:-false}" = true ] && [ "$(cat "$MOCK_TASK_ATTEMPTS")" -eq 1 ]; then
      printf '%s\n' '{"events":[{"message":"Error: P1001: Can not reach database server"}]}'
    else
      printf '%s\n' '{"events":[{"message":"All migrations have been successfully applied."}]}'
    fi
    ;;
  *) exit 3 ;;
esac
EOF

chmod +x "$test_root/bin/terraform" "$test_root/bin/aws"
export MOCK_AWS_CALLS="$test_root/aws-calls.txt"
export MOCK_PROXY_ATTEMPTS="$test_root/proxy-attempts.txt"
export MOCK_TASK_ATTEMPTS="$test_root/task-attempts.txt"
export MIGRATION_PROXY_POLL_INTERVAL_SECONDS=0
export MIGRATION_PROXY_MAX_ATTEMPTS=3
export MIGRATION_TASK_RETRY_DELAY_SECONDS=0

PATH="$test_root/bin:$PATH" GITHUB_RUN_ID=123 \
  bash scripts/run-ecs-migration.sh env/dev "$test_root/evidence"

jq -e '.status == "passed" and .proxy == "eepistore-dev-proxy"' \
  "$test_root/evidence/proxy-readiness.json" > /dev/null
jq -e '.events | length == 1' "$test_root/evidence/logs.json" > /dev/null
grep -Fx 'PASS migration' "$test_root/evidence/status.txt" > /dev/null
test "$(cat "$test_root/proxy-attempts.txt")" = 2
jq -e 'length == 1 and .[0].status == "passed"' "$test_root/evidence/attempts.json" > /dev/null

rm -f "$MOCK_TASK_ATTEMPTS"
export MOCK_TRANSIENT_P1001=true
PATH="$test_root/bin:$PATH" GITHUB_RUN_ID=124 \
  bash scripts/run-ecs-migration.sh env/dev "$test_root/retry-evidence"

test "$(cat "$MOCK_TASK_ATTEMPTS")" = 2
grep -Fx 'PASS migration' "$test_root/retry-evidence/status.txt" > /dev/null
jq -e 'length == 2 and .[0].status == "retryable-failure" and .[1].status == "passed"' \
  "$test_root/retry-evidence/attempts.json" > /dev/null

rm -f "$MOCK_TASK_ATTEMPTS"
unset MOCK_TRANSIENT_P1001
export MOCK_NONRETRYABLE_FAILURE=true
if PATH="$test_root/bin:$PATH" GITHUB_RUN_ID=125 \
  bash scripts/run-ecs-migration.sh env/dev "$test_root/failure-evidence"; then
  echo "Expected non-retryable migration failure" >&2
  exit 1
fi

test "$(cat "$MOCK_TASK_ATTEMPTS")" = 1
jq -e 'length == 1 and .[0].status == "failed"' \
  "$test_root/failure-evidence/attempts.json" > /dev/null
