#!/usr/bin/env bash
set -euo pipefail

test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

cat > "$test_root/no-drift.json" <<'EOF'
{
  "resource_changes": [
    {"address":"aws_vpc.main","change":{"actions":["no-op"]}}
  ]
}
EOF

cat > "$test_root/drift.json" <<'EOF'
{
  "resource_changes": [
    {"address":"aws_vpc.main","change":{"actions":["no-op"]}},
    {"address":"module.rds.aws_db_proxy.main[0]","change":{"actions":["update"]}}
  ]
}
EOF

bash scripts/check-terraform-plan-drift.sh "$test_root/no-drift.json"

set +e
bash scripts/check-terraform-plan-drift.sh "$test_root/drift.json" \
  > "$test_root/drift.out" 2> "$test_root/drift.err"
drift_code=$?
set -e

test "$drift_code" -eq 2
grep -Fx 'module.rds.aws_db_proxy.main[0]: update' "$test_root/drift.err" > /dev/null

grep -Fq 'iam_auth                  = "DISABLED"' modules/rds/proxy.tf
grep -Fq "terraform -chdir=\"\$TF_DIR\" show -json" scripts/verify-aws-post-apply.sh
grep -Fq 'check-terraform-plan-drift.sh' scripts/verify-aws-post-apply.sh
