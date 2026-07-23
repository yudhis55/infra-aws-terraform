#!/usr/bin/env bash
set -euo pipefail

tf_dir="${1:-env/dev}"
expected_url="${2:?expected application URL is required}"
expected_digest="${3:?expected image digest is required}"
expected_commit="${4:?expected application commit is required}"
out_dir="${5:-experiment-evidence/preflight}"

mkdir -p "$out_dir"
application_url="$(terraform -chdir="$tf_dir" output -raw application_url)"
cluster="$(terraform -chdir="$tf_dir" output -raw ecs_cluster_name)"
service="$(terraform -chdir="$tf_dir" output -raw ecs_service_name)"

test "$application_url" = "$expected_url"
test "${expected_url#https://}" != "$expected_url"
test "${expected_digest#sha256:}" != "$expected_digest"

aws ecs describe-services --cluster "$cluster" --services "$service" > "$out_dir/ecs-service.json"
task_definition="$(jq -r '.services[0].taskDefinition // empty' "$out_dir/ecs-service.json")"
test -n "$task_definition"
aws ecs describe-task-definition \
  --task-definition "$task_definition" > "$out_dir/task-definition.json"
active_image="$(jq -r '.taskDefinition.containerDefinitions[] | select(.name == "app") | .image' \
  "$out_dir/task-definition.json")"
test "${active_image##*@}" = "$expected_digest"
repository_path="${active_image#*/}"
repository_name="${repository_path%%@*}"
aws ecr describe-images \
  --repository-name "$repository_name" \
  --image-ids "imageDigest=$expected_digest" > "$out_dir/ecr-image.json"
jq -e --arg commit "$expected_commit" \
  '.imageDetails[0].imageTags // [] | index($commit) != null' \
  "$out_dir/ecr-image.json" > /dev/null
jq -e \
  '.taskDefinition.containerDefinitions[] | select(.name == "app") | .readonlyRootFilesystem == true' \
  "$out_dir/task-definition.json" > /dev/null

curl --fail --silent --show-error --max-time 30 \
  "$expected_url/api/health" > "$out_dir/health.json"
curl --fail --silent --show-error --max-time 30 \
  "$expected_url/api/readiness" > "$out_dir/readiness.json"
jq -e '.status == "ok"' "$out_dir/health.json" > /dev/null
jq -e '.status == "ok"' "$out_dir/readiness.json" > /dev/null

jq -n \
  --arg application_url "$application_url" \
  --arg cluster "$cluster" \
  --arg service "$service" \
  --arg task_definition "$task_definition" \
  --arg image "$active_image" \
  --arg expected_commit "$expected_commit" \
  '{
    status: "passed",
    applicationUrl: $application_url,
    cluster: $cluster,
    service: $service,
    taskDefinition: $task_definition,
    image: $image,
    appCommit: $expected_commit,
    readonlyRootFilesystem: true
  }' > "$out_dir/preflight.json"
