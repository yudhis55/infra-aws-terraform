#!/usr/bin/env bash
set -euo pipefail

grep -Fq 'delete = "60m"' modules/ecs/main.tf

if grep -Fq 'delete = "45m"' modules/ecs/main.tf; then
  echo "ECS service delete timeout regressed to the observed failing boundary" >&2
  exit 1
fi
