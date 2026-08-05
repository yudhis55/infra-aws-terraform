#!/usr/bin/env bash
set -euo pipefail

plan_json="${1:?Usage: check-terraform-plan-drift.sh <terraform-plan.json>}"

if ! jq -e 'type == "object" and (.resource_changes | type == "array")' "$plan_json" > /dev/null; then
  echo "Terraform plan JSON is invalid or has no resource_changes array" >&2
  exit 1
fi

change_count="$(jq '[
  .resource_changes[]
  | select(.change.actions != ["no-op"])
] | length' "$plan_json")"

if [[ "$change_count" -eq 0 ]]; then
  exit 0
fi

jq -r '
  .resource_changes[]
  | select(.change.actions != ["no-op"])
  | "\(.address): \(.change.actions | join(","))"
' "$plan_json" >&2
exit 2
