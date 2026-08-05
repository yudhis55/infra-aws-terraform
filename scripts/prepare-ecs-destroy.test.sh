#!/usr/bin/env bash
set -euo pipefail

test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/evidence"

cat > "$test_root/bin/terraform" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${MOCK_MISSING_OUTPUTS:-false}" = true ]; then exit 1; fi
case "${!#}" in
  ecs_cluster_name) echo eepistore-cluster ;;
  ecs_service_name) echo eepistore-service ;;
  target_group_arn) echo arn:aws:elasticloadbalancing:test:targetgroup/eepistore/123 ;;
  alb_arn) echo arn:aws:elasticloadbalancing:test:loadbalancer/app/eepistore/456 ;;
  *) exit 2 ;;
esac
EOF

cat > "$test_root/bin/aws" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_AWS_CALLS"
case "$1 $2" in
  "elbv2 modify-load-balancer-attributes") printf '%s\n' '{"Attributes":[{"Key":"access_logs.s3.enabled","Value":"false"}]}' ;;
  "ecs describe-services")
    calls=0
    if [ -f "$MOCK_SERVICE_CALLS" ]; then calls="$(cat "$MOCK_SERVICE_CALLS")"; fi
    calls=$((calls + 1))
    echo "$calls" > "$MOCK_SERVICE_CALLS"
    if [ "$calls" -eq 1 ]; then
      printf '%s\n' '{"services":[{"status":"ACTIVE","desiredCount":1,"runningCount":1,"pendingCount":0}],"failures":[]}'
    else
      printf '%s\n' '{"services":[{"status":"ACTIVE","desiredCount":0,"runningCount":0,"pendingCount":0}],"failures":[]}'
    fi
    ;;
  "application-autoscaling register-scalable-target") printf '%s\n' '{}' ;;
  "ecs update-service") printf '%s\n' '{"service":{"desiredCount":0}}' ;;
  "elbv2 describe-target-health") printf '%s\n' '{"TargetHealthDescriptions":[]}' ;;
  *) exit 3 ;;
esac
EOF

chmod +x "$test_root/bin/terraform" "$test_root/bin/aws"
export MOCK_AWS_CALLS="$test_root/aws-calls.txt"
export MOCK_SERVICE_CALLS="$test_root/service-calls.txt"
export ECS_DRAIN_POLL_INTERVAL_SECONDS=0
export ECS_DRAIN_MAX_ATTEMPTS=3

PATH="$test_root/bin:$PATH" \
  bash scripts/prepare-ecs-destroy.sh env/dev "$test_root/evidence"

jq -e '.status == "passed" and .service == "eepistore-service" and .serviceDrained and .targetsDrained and .accessLoggingDisabled' \
  "$test_root/evidence/result.json" > /dev/null
grep -F 'elbv2 modify-load-balancer-attributes' "$test_root/aws-calls.txt" > /dev/null
grep -F -- '--attributes Key=access_logs.s3.enabled,Value=false' "$test_root/aws-calls.txt" > /dev/null
grep -F 'application-autoscaling register-scalable-target' "$test_root/aws-calls.txt" > /dev/null
grep -F -- '--suspended-state DynamicScalingInSuspended=true,ScheduledScalingSuspended=true,DynamicScalingOutSuspended=true' \
  "$test_root/aws-calls.txt" > /dev/null
grep -F 'ecs update-service' "$test_root/aws-calls.txt" > /dev/null

mkdir -p "$test_root/recovery-evidence"
MOCK_MISSING_OUTPUTS=true PATH="$test_root/bin:$PATH" \
  bash scripts/prepare-ecs-destroy.sh env/dev "$test_root/recovery-evidence"
jq -e '.status == "not-found" and (.cluster | length == 0) and (.albArn | length == 0)' \
  "$test_root/recovery-evidence/result.json" > /dev/null
