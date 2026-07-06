#!/usr/bin/env bash
set -euo pipefail

TF_DIR="${1:-env/dev}"
OUT_DIR="$(pwd)/${2:-verification-evidence}"

mkdir -p "$OUT_DIR"
failures=0

log_status() {
  echo "$1" >> "$OUT_DIR/verification-status.txt"
  if [[ "$1" == FAIL* ]]; then
    failures=$((failures + 1))
  fi
}

capture() {
  local name="$1"
  shift

  if "$@" > "$OUT_DIR/${name}.json" 2> "$OUT_DIR/${name}.err"; then
    log_status "PASS ${name}"
  else
    log_status "FAIL ${name}; see ${name}.err"
  fi
}

read_output() {
  local key="$1"
  jq -r --arg key "$key" '.[$key].value // empty' "$OUT_DIR/terraform-output.json"
}

wait_for_ecs_capacity() {
  local cluster_name="$1"
  local attempts="${2:-40}"
  local delay_seconds="${3:-15}"
  local count

  for _ in $(seq 1 "$attempts"); do
    count="$(aws ecs list-container-instances --cluster "$cluster_name" | jq '.containerInstanceArns | length')" || count=0
    if [ "$count" -gt 0 ]; then
      log_status "PASS ecs-container-instances: $count registered"
      return 0
    fi
    sleep "$delay_seconds"
  done

  log_status "FAIL ecs-container-instances: no registered ECS container instances"
  return 1
}

terraform -chdir="$TF_DIR" output -json > "$OUT_DIR/terraform-output.json"

set +e
terraform -chdir="$TF_DIR" plan -detailed-exitcode -out="$OUT_DIR/drift.tfplan" > "$OUT_DIR/drift-plan.txt"
drift_code=$?
set -e

case "$drift_code" in
  0) log_status "PASS terraform-drift: no drift detected" ;;
  2) log_status "FAIL terraform-drift: drift detected; see drift-plan.txt" ;;
  *) log_status "FAIL terraform-drift: terraform plan failed with exit code $drift_code"; exit "$drift_code" ;;
esac

vpc_id="$(read_output vpc_id)"
alb_arn="$(read_output alb_arn)"
alb_dns_name="$(read_output alb_dns_name)"
target_group_arn="$(read_output target_group_arn)"
cluster_name="$(read_output ecs_cluster_name)"
service_name="$(read_output ecs_service_name)"
asg_name="$(read_output asg_name)"
rds_instance_id="$(read_output rds_instance_id)"
rds_proxy_id="$(read_output rds_proxy_id)"
s3_bucket_name="$(read_output s3_bucket_name)"
cloudfront_distribution_id="$(read_output cloudfront_distribution_id)"
waf_web_acl_arn="$(read_output waf_web_acl_arn)"
application_url="$(read_output application_url)"

jq -n \
  --arg vpc_id "$vpc_id" \
  --arg alb_arn "$alb_arn" \
  --arg target_group_arn "$target_group_arn" \
  --arg cluster_name "$cluster_name" \
  --arg service_name "$service_name" \
  --arg asg_name "$asg_name" \
  --arg rds_instance_id "$rds_instance_id" \
  --arg rds_proxy_id "$rds_proxy_id" \
  --arg s3_bucket_name "$s3_bucket_name" \
  --arg cloudfront_distribution_id "$cloudfront_distribution_id" \
  --arg waf_web_acl_arn "$waf_web_acl_arn" \
  --arg application_url "$application_url" \
  '{
    vpc_id: $vpc_id,
    alb_arn: $alb_arn,
    target_group_arn: $target_group_arn,
    ecs_cluster_name: $cluster_name,
    ecs_service_name: $service_name,
    asg_name: $asg_name,
    rds_instance_id: $rds_instance_id,
    rds_proxy_id: $rds_proxy_id,
    s3_bucket_name: $s3_bucket_name,
    cloudfront_distribution_id: $cloudfront_distribution_id,
    waf_web_acl_arn: $waf_web_acl_arn,
    application_url: $application_url
  }' > "$OUT_DIR/resource-summary.json"

if [ -n "$vpc_id" ]; then
  capture vpc aws ec2 describe-vpcs --vpc-ids "$vpc_id"
  capture subnets aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id"
  capture route-tables aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id"
fi

if [ -n "$alb_arn" ]; then
  capture alb aws elbv2 describe-load-balancers --load-balancer-arns "$alb_arn"
  capture alb-listeners aws elbv2 describe-listeners --load-balancer-arn "$alb_arn"
fi

if [ -n "$target_group_arn" ]; then
  capture target-health aws elbv2 describe-target-health --target-group-arn "$target_group_arn"
fi

if [ -n "$cluster_name" ] && [ -n "$service_name" ]; then
  if wait_for_ecs_capacity "$cluster_name"; then
    aws ecs wait services-stable --cluster "$cluster_name" --services "$service_name" \
      && log_status "PASS ecs-service-stable" \
      || log_status "FAIL ecs-service-stable"
  fi

  capture ecs-service aws ecs describe-services --cluster "$cluster_name" --services "$service_name"
  aws ecs list-tasks --cluster "$cluster_name" --service-name "$service_name" > "$OUT_DIR/ecs-task-arns.json"
  task_arns="$(jq -r '.taskArns[]?' "$OUT_DIR/ecs-task-arns.json" | tr '\n' ' ')"
  if [ -n "$task_arns" ]; then
    # shellcheck disable=SC2086
    capture ecs-tasks aws ecs describe-tasks --cluster "$cluster_name" --tasks $task_arns
  else
    log_status "FAIL ecs-tasks: no running service tasks found"
  fi
fi

if [ -n "$asg_name" ]; then
  capture asg aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$asg_name"
fi

if [ -n "$rds_instance_id" ]; then
  capture rds-instance aws rds describe-db-instances --db-instance-identifier "$rds_instance_id"
fi

if [ -n "$rds_proxy_id" ]; then
  capture rds-proxy aws rds describe-db-proxies --db-proxy-name "$rds_proxy_id"
  capture rds-proxy-targets aws rds describe-db-proxy-targets --db-proxy-name "$rds_proxy_id"
fi

if [ -n "$s3_bucket_name" ]; then
  capture s3-public-access-block aws s3api get-public-access-block --bucket "$s3_bucket_name"
  capture s3-encryption aws s3api get-bucket-encryption --bucket "$s3_bucket_name"
fi

if [ -n "$cloudfront_distribution_id" ]; then
  capture cloudfront-distribution aws cloudfront get-distribution --id "$cloudfront_distribution_id"
fi

if [ -n "$waf_web_acl_arn" ] && [ "$waf_web_acl_arn" != "null" ]; then
  waf_name="$(echo "$waf_web_acl_arn" | awk -F'/' '{print $(NF-1)}')"
  waf_id="$(echo "$waf_web_acl_arn" | awk -F'/' '{print $NF}')"
  if [ -n "$waf_name" ] && [ -n "$waf_id" ]; then
    capture waf-web-acl aws wafv2 get-web-acl --scope REGIONAL --name "$waf_name" --id "$waf_id"
  fi
fi

if [ -n "$alb_dns_name" ]; then
  echo "$alb_dns_name" > "$OUT_DIR/alb-dns-name.txt"
fi

if [ -n "$application_url" ]; then
  curl --fail --silent --show-error --max-time 30 "$application_url/api/health" > "$OUT_DIR/health.json" \
    && log_status "PASS runtime-health" \
    || log_status "FAIL runtime-health"

  curl --fail --silent --show-error --max-time 30 "$application_url/api/readiness" > "$OUT_DIR/readiness.json" \
    && log_status "PASS runtime-readiness" \
    || log_status "FAIL runtime-readiness"
fi

if [ "$failures" -gt 0 ]; then
  echo "Post-apply verification found $failures failure(s); evidence written to $OUT_DIR"
  exit 1
fi

echo "Post-apply verification evidence written to $OUT_DIR"
