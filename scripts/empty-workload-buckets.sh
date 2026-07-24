#!/usr/bin/env bash
set -euo pipefail

project_name="${1:?project name is required}"
environment="${2:-dev}"

bucket_prefixes=(
  "${project_name}-${environment}-public-media-"
  "${project_name}-${environment}-private-documents-"
  "${project_name}-${environment}-alb-logs-"
)

all_buckets="$(aws s3api list-buckets --query 'Buckets[].Name' --output json)"

for prefix in "${bucket_prefixes[@]}"; do
  mapfile -t buckets < <(
    jq -r --arg prefix "$prefix" '.[] | select(startswith($prefix))' <<<"$all_buckets"
  )

  for bucket in "${buckets[@]}"; do
    echo "Purging workload bucket $bucket."
    aws s3 rm "s3://${bucket}" --recursive >/dev/null

    while true; do
      versions="$(aws s3api list-object-versions --bucket "$bucket" --output json)"
      delete_payload="$(
        jq '{
          Objects: (
            ((.Versions // []) + (.DeleteMarkers // []))
            | map({Key: .Key, VersionId: .VersionId})
          ),
          Quiet: true
        }' <<<"$versions"
      )"
      object_count="$(jq '.Objects | length' <<<"$delete_payload")"

      if [ "$object_count" -eq 0 ]; then
        break
      fi

      payload_file="$(mktemp)"
      printf '%s\n' "$delete_payload" >"$payload_file"
      aws s3api delete-objects \
        --bucket "$bucket" \
        --delete "file://${payload_file}" \
        >/dev/null
      rm -f "$payload_file"
    done

    echo "Bucket $bucket is empty, including object versions and delete markers."
  done
done
