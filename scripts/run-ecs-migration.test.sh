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
    printf '%s\n' '{"tasks":[{"containers":[{"name":"app","exitCode":0}]}],"failures":[]}'
    ;;
  "logs get-log-events") printf '%s\n' '{"events":[{"message":"All migrations have been successfully applied."}]}' ;;
  *) exit 3 ;;
esac
EOF

chmod +x "$test_root/bin/terraform" "$test_root/bin/aws"
export MOCK_AWS_CALLS="$test_root/aws-calls.txt"
export MOCK_PROXY_ATTEMPTS="$test_root/proxy-attempts.txt"
export MIGRATION_PROXY_POLL_INTERVAL_SECONDS=0
export MIGRATION_PROXY_MAX_ATTEMPTS=3

PATH="$test_root/bin:$PATH" GITHUB_RUN_ID=123 \
  bash scripts/run-ecs-migration.sh env/dev "$test_root/evidence"

jq -e '.status == "passed" and .proxy == "eepistore-dev-proxy"' \
  "$test_root/evidence/proxy-readiness.json" > /dev/null
jq -e '.events | length == 1' "$test_root/evidence/logs.json" > /dev/null
grep -Fx 'PASS migration' "$test_root/evidence/status.txt" > /dev/null
test "$(cat "$test_root/proxy-attempts.txt")" = 2
