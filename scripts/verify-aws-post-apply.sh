#!/usr/bin/env bash
set -euo pipefail

TF_DIR="${1:-env/dev}"
OUT_DIR="$(pwd)/${2:-verification-evidence}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$OUT_DIR"
mkdir -p "$OUT_DIR/timing"
failures=0
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
started_epoch="$(date +%s)"

write_timing() {
  local exit_code="$?"
  local ended_at
  local ended_epoch
  local status="passed"
  ended_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  ended_epoch="$(date +%s)"
  if [ "$exit_code" -ne 0 ]; then status="failed"; fi
  jq -n \
    --arg status "$status" \
    --arg startedAt "$started_at" \
    --arg endedAt "$ended_at" \
    --argjson durationSeconds "$((ended_epoch - started_epoch))" \
    '{status:$status, startedAt:$startedAt, endedAt:$endedAt, durationSeconds:$durationSeconds}' \
    > "$OUT_DIR/timing/verification-timing.json"
}
trap write_timing EXIT

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

assert_json() {
  local name="$1"
  local file="$2"
  local filter="$3"

  if jq -e "$filter" "$file" > /dev/null 2> "$OUT_DIR/${name}.err"; then
    log_status "PASS ${name}"
  else
    log_status "FAIL ${name}; assertion '${filter}' did not match"
  fi
}

verify_json_endpoint() {
  local name="$1"
  local url="$2"
  local attempts="${3:-1}"
  local delay_seconds="${4:-0}"
  local status
  local attempt
  local failure_reason="request was not attempted"

  for attempt in $(seq 1 "$attempts"); do
    if status="$(curl --silent --show-error --max-time 30 --output "$OUT_DIR/${name}.json" --write-out "%{http_code}" "$url" 2> "$OUT_DIR/${name}.err")"; then
      if [ "$status" = "200" ] && jq -e '.status == "ok"' "$OUT_DIR/${name}.json" > /dev/null 2> "$OUT_DIR/${name}.err"; then
        jq -n --argjson attempts "$attempt" --arg status "$status" \
          '{status:"passed",attempts:$attempts,httpStatus:$status}' \
          > "$OUT_DIR/${name}-attempts.json"
        log_status "PASS runtime-${name}: ready after ${attempt} attempt(s)"
        return 0
      fi
      if [ "$status" != "200" ]; then
        failure_reason="HTTP $status"
      else
        failure_reason="response is not JSON status=ok"
      fi
    else
      failure_reason="curl failed"
    fi
    if [ "$attempt" -lt "$attempts" ]; then sleep "$delay_seconds"; fi
  done

  jq -n --argjson attempts "$attempts" --arg reason "$failure_reason" \
    '{status:"failed",attempts:$attempts,reason:$reason}' \
    > "$OUT_DIR/${name}-attempts.json"
  echo "$failure_reason after $attempts attempt(s)" > "$OUT_DIR/${name}.err"
  log_status "FAIL runtime-${name}: $failure_reason after $attempts attempt(s)"
  return 1
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

if [[ "$drift_code" != "0" && "$drift_code" != "2" ]]; then
  log_status "FAIL terraform-drift: terraform plan failed with exit code $drift_code"
  exit "$drift_code"
fi

terraform -chdir="$TF_DIR" show -json "$OUT_DIR/drift.tfplan" > "$OUT_DIR/drift-plan.json"
set +e
"$SCRIPT_DIR/check-terraform-plan-drift.sh" "$OUT_DIR/drift-plan.json"
drift_check_code=$?
set -e

case "$drift_check_code" in
  0) log_status "PASS terraform-drift: no drift detected" ;;
  2) log_status "FAIL terraform-drift: drift detected; see drift-plan.txt and drift-plan.json" ;;
  *) log_status "FAIL terraform-drift: plan JSON validation failed with exit code $drift_check_code"; exit "$drift_check_code" ;;
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
s3_public_bucket_name="$(read_output s3_public_bucket_name)"
s3_private_bucket_name="$(read_output s3_private_bucket_name)"
cloudfront_distribution_id="$(read_output cloudfront_distribution_id)"
cloudfront_media_url="$(read_output cloudfront_media_url)"
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
  --arg s3_public_bucket_name "$s3_public_bucket_name" \
  --arg s3_private_bucket_name "$s3_private_bucket_name" \
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
    s3_public_bucket_name: $s3_public_bucket_name,
    s3_private_bucket_name: $s3_private_bucket_name,
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
  assert_json alb-private-resource-shape "$OUT_DIR/alb.json" \
    '(.LoadBalancers | length) == 1 and .LoadBalancers[0].Scheme == "internet-facing"'
  assert_json alb-https-listener "$OUT_DIR/alb-listeners.json" \
    '[.Listeners[] | select(.Port == 443 and .Protocol == "HTTPS")] | length == 1'
  assert_json alb-http-redirect "$OUT_DIR/alb-listeners.json" \
    '[.Listeners[] | select(.Port == 80) | .DefaultActions[] | select(.Type == "redirect" and .RedirectConfig.Protocol == "HTTPS")] | length == 1'
fi

if [ -n "$target_group_arn" ]; then
  capture target-health aws elbv2 describe-target-health --target-group-arn "$target_group_arn"
  assert_json target-health-all-healthy "$OUT_DIR/target-health.json" \
    '.TargetHealthDescriptions | length > 0 and all(.[]; .TargetHealth.State == "healthy")'
fi

if [ -n "$cluster_name" ] && [ -n "$service_name" ]; then
  if wait_for_ecs_capacity "$cluster_name"; then
    if aws ecs wait services-stable --cluster "$cluster_name" --services "$service_name"; then
      log_status "PASS ecs-service-stable"
    else
      log_status "FAIL ecs-service-stable"
    fi
  fi

  capture ecs-service aws ecs describe-services --cluster "$cluster_name" --services "$service_name"
  capture ecs-scaling-policies aws application-autoscaling describe-scaling-policies \
    --service-namespace ecs --resource-id "service/$cluster_name/$service_name"
  assert_json ecs-scaling-policies-complete "$OUT_DIR/ecs-scaling-policies.json" \
    '([.ScalingPolicies[].TargetTrackingScalingPolicyConfiguration.PredefinedMetricSpecification.PredefinedMetricType] | index("ECSServiceAverageCPUUtilization")) != null and ([.ScalingPolicies[].TargetTrackingScalingPolicyConfiguration.PredefinedMetricSpecification.PredefinedMetricType] | index("ECSServiceAverageMemoryUtilization")) != null and ([.ScalingPolicies[].TargetTrackingScalingPolicyConfiguration.PredefinedMetricSpecification.PredefinedMetricType] | index("ALBRequestCountPerTarget")) != null'
  aws ecs list-tasks --cluster "$cluster_name" --service-name "$service_name" > "$OUT_DIR/ecs-task-arns.json"
  task_arns="$(jq -r '.taskArns[]?' "$OUT_DIR/ecs-task-arns.json" | tr '\n' ' ')"
  if [ -n "$task_arns" ]; then
    # shellcheck disable=SC2086
    capture ecs-tasks aws ecs describe-tasks --cluster "$cluster_name" --tasks $task_arns
    task_definition_arn="$(jq -r '.tasks[0].taskDefinitionArn // empty' "$OUT_DIR/ecs-tasks.json")"
    if [ -n "$task_definition_arn" ]; then
      capture ecs-task-definition aws ecs describe-task-definition \
        --task-definition "$task_definition_arn"
      assert_json ecs-read-only-root "$OUT_DIR/ecs-task-definition.json" \
        '.taskDefinition.containerDefinitions[] | select(.name == "app") | .readonlyRootFilesystem == true'
      deployed_image="$(jq -r '.taskDefinition.containerDefinitions[] | select(.name == "app") | .image' "$OUT_DIR/ecs-task-definition.json")"
      if [ "$deployed_image" = "${TF_VAR_app_image_uri:-}" ] && [[ "$deployed_image" =~ @sha256:[0-9a-f]{64}$ ]]; then
        log_status "PASS ecs-exact-immutable-image"
      else
        log_status "FAIL ecs-exact-immutable-image: deployed image does not match TF_VAR_app_image_uri digest"
      fi
    fi
  else
    log_status "FAIL ecs-tasks: no running service tasks found"
  fi
fi

if [ -n "$asg_name" ]; then
  capture asg aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$asg_name"
fi

if [ -n "$rds_instance_id" ]; then
  capture rds-instance aws rds describe-db-instances --db-instance-identifier "$rds_instance_id"
  assert_json rds-private-multi-az "$OUT_DIR/rds-instance.json" \
    '(.DBInstances | length) == 1 and .DBInstances[0].PubliclyAccessible == false and .DBInstances[0].MultiAZ == true and .DBInstances[0].StorageEncrypted == true'
fi

if [ -n "$rds_proxy_id" ]; then
  capture rds-proxy aws rds describe-db-proxies --db-proxy-name "$rds_proxy_id"
  capture rds-proxy-targets aws rds describe-db-proxy-targets --db-proxy-name "$rds_proxy_id"
  assert_json rds-proxy-target-available "$OUT_DIR/rds-proxy-targets.json" \
    '.Targets | length > 0 and all(.[]; .TargetHealth.State == "AVAILABLE")'
fi

for bucket_class in public private; do
  bucket_variable="s3_${bucket_class}_bucket_name"
  bucket_name="${!bucket_variable}"
  if [ -n "$bucket_name" ]; then
    capture "s3-${bucket_class}-public-access-block" aws s3api get-public-access-block \
      --bucket "$bucket_name"
    capture "s3-${bucket_class}-encryption" aws s3api get-bucket-encryption \
      --bucket "$bucket_name"
    capture "s3-${bucket_class}-cors" aws s3api get-bucket-cors --bucket "$bucket_name"
    assert_json "s3-${bucket_class}-not-public" \
      "$OUT_DIR/s3-${bucket_class}-public-access-block.json" \
      '.PublicAccessBlockConfiguration | .BlockPublicAcls and .IgnorePublicAcls and .BlockPublicPolicy and .RestrictPublicBuckets'
    assert_json "s3-${bucket_class}-cors-no-wildcard" \
      "$OUT_DIR/s3-${bucket_class}-cors.json" \
      '[.CORSRules[].AllowedOrigins[]] | all(. != "*")'
  fi
done

if [ -n "$cloudfront_distribution_id" ]; then
  capture cloudfront-distribution aws cloudfront get-distribution --id "$cloudfront_distribution_id"
  media_hostname="${cloudfront_media_url#https://}"
  media_hostname="${media_hostname%%/*}"
  assert_json cloudfront-oac-and-alias "$OUT_DIR/cloudfront-distribution.json" \
    ".Distribution.DistributionConfig | (.Aliases.Items | index(\"$media_hostname\")) != null and (.Origins.Items | all(.OriginAccessControlId != \"\"))"
fi

if [ -n "$waf_web_acl_arn" ] && [ "$waf_web_acl_arn" != "null" ]; then
  waf_name="$(echo "$waf_web_acl_arn" | awk -F'/' '{print $(NF-1)}')"
  waf_id="$(echo "$waf_web_acl_arn" | awk -F'/' '{print $NF}')"
  if [ -n "$waf_name" ] && [ -n "$waf_id" ]; then
    capture waf-web-acl aws wafv2 get-web-acl --scope REGIONAL --name "$waf_name" --id "$waf_id"
    capture waf-alb-association aws wafv2 get-web-acl-for-resource --resource-arn "$alb_arn"
    assert_json waf-attached-to-alb "$OUT_DIR/waf-alb-association.json" \
      '.WebACL.ARN != null'
    assert_json waf-experiment-endpoint-default-deny "$OUT_DIR/waf-web-acl.json" \
      '([.WebACL.Rules[].Name] | index("ExperimentEndpointPermanentDeny")) != null and ([.WebACL.Rules[].Name] | index("ExperimentRateLimit")) == null and ([.WebACL.Rules[].Name] | index("ExperimentPerformanceAllow")) == null'
  fi
fi

capture cloudwatch-alarms aws cloudwatch describe-alarms \
  --alarm-name-prefix "${cluster_name%-cluster}"

if [ -n "$alb_dns_name" ]; then
  echo "$alb_dns_name" > "$OUT_DIR/alb-dns-name.txt"
fi

if [ -n "$application_url" ]; then
  verify_json_endpoint "health" "$application_url/api/health"
  verify_json_endpoint "readiness" "$application_url/api/readiness" 12 15
  experiment_status="$(curl --silent --show-error --max-time 30 --output "$OUT_DIR/experiment-endpoint-deny.json" --write-out "%{http_code}" "$application_url/api/experiment/rate-limit" || true)"
  if [ "$experiment_status" = "403" ]; then
    log_status "PASS runtime-experiment-endpoint-default-deny"
  else
    log_status "FAIL runtime-experiment-endpoint-default-deny: HTTP $experiment_status"
  fi
fi

if [ "$failures" -gt 0 ]; then
  echo "Post-apply verification found $failures failure(s); evidence written to $OUT_DIR"
  exit 1
fi

echo "Post-apply verification evidence written to $OUT_DIR"
