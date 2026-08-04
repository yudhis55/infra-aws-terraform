#!/usr/bin/env bash
set -euo pipefail

test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/evidence"

cat > "$test_root/bin/aws" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$1 $2" in
  "cloudfront list-distributions")
    printf '%s\n' '{"DistributionList":{"Items":null}}'
    ;;
  "ecr describe-repositories")
    printf '%s\n' '1'
    ;;
  "ecs describe-clusters")
    # AWS CLI emits an empty string for a JMESPath query with no matching cluster.
    :
    ;;
  "secretsmanager list-secrets")
    printf '%s\n' 'None'
    ;;
  *)
    printf '%s\n' '0'
    ;;
esac
EOF
chmod +x "$test_root/bin/aws"

PATH="$test_root/bin:$PATH" bash scripts/verify-aws-post-destroy.sh \
  eepistore dev "$test_root/evidence"

jq -e '
  .status == "passed" and
  .remaining.cloudFrontDistributions == 0 and
  .retainedPrerequisites.ecrRepositories == 1
' "$test_root/evidence/aws-resource-audit.json" > /dev/null
grep -Fx 'PASS aws-workload-resources-absent' \
  "$test_root/evidence/verification-status.txt" > /dev/null
