#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY_FILE="$ROOT_DIR/modules/ecs/alb-logs.tf"

grep -Fq 'Service = "logdelivery.elasticloadbalancing.amazonaws.com"' "$POLICY_FILE"
grep -Fq "/alb/AWSLogs/\${data.aws_caller_identity.current.account_id}/*" "$POLICY_FILE"
grep -Fq '"aws:SourceArn"' "$POLICY_FILE"
grep -Fq ':loadbalancer/*' "$POLICY_FILE"

if grep -Fq 'aws_elb_service_account' "$POLICY_FILE"; then
  echo "Legacy regional ELB service-account policy must not be used." >&2
  exit 1
fi

echo "ALB access-log bucket policy regression checks passed."
