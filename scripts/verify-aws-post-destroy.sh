#!/usr/bin/env bash
set -euo pipefail

project="${1:-eepistore}"
environment="${2:-dev}"
out_dir="${3:-destroy-evidence}"
mkdir -p "$out_dir"

normalize_count() {
  local label="$1"
  local value="${2:-}"

  case "$value" in
    "" | null | None)
      printf '0\n'
      ;;
    *[!0-9]*)
      printf 'unexpected non-numeric AWS count for %s: %s\n' "$label" "$value" >&2
      return 1
      ;;
    *)
      printf '%s\n' "$value"
      ;;
  esac
}

vpcs="$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$project-$environment-vpc" --query 'length(Vpcs)' --output json)"
nats="$(aws ec2 describe-nat-gateways --filter "Name=tag:Name,Values=$project-$environment-nat-*" "Name=state,Values=pending,available,deleting,failed" --query 'length(NatGateways)' --output json)"
instances="$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$project-ecs-instance,$project-$environment-experiment-agent" "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down" --query 'length(Reservations[].Instances[])' --output json)"
asgs="$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$project-asg" --query 'length(AutoScalingGroups)' --output json)"
albs="$(aws elbv2 describe-load-balancers --names "$project-alb" --query 'length(LoadBalancers)' --output json 2>/dev/null || echo 0)"
rds="$(aws rds describe-db-instances --db-instance-identifier "$project-$environment-db" --query 'length(DBInstances)' --output json 2>/dev/null || echo 0)"
proxies="$(aws rds describe-db-proxies --db-proxy-name "$project-$environment-proxy" --query 'length(DBProxies)' --output json 2>/dev/null || echo 0)"
bootstrap_ecr="$(aws ecr describe-repositories --repository-names "$project-repo" --query 'length(repositories)' --output json 2>/dev/null || echo 0)"
buckets="$(aws s3api list-buckets --query "length(Buckets[?starts_with(Name, '$project-$environment-public-media-') || starts_with(Name, '$project-$environment-private-documents-') || starts_with(Name, '$project-$environment-alb-logs-')])" --output json)"
cloudfront="$(aws cloudfront list-distributions --output json | jq --arg alias "media.eepistore.web.id" '[.DistributionList.Items[]? | select(any(.Aliases.Items[]?; . == $alias))] | length')"
active_secrets="$(aws secretsmanager list-secrets --include-planned-deletion --filters Key=name,Values="$project-$environment-app-secrets" --query 'length(SecretList[?DeletedDate == null])' --output json)"
flow_log_groups="$(aws logs describe-log-groups --log-group-name-prefix "/aws/vpc/flowlogs/$project" --query "length(logGroups[?logGroupName == '/aws/vpc/flowlogs/$project'])" --output json)"

cluster_json="$(aws ecs describe-clusters --clusters "$project-cluster" --include ATTACHMENTS --query 'clusters[0]' --output json)"
if [ -z "$cluster_json" ] || [ "$cluster_json" = null ] || [ "$cluster_json" = None ]; then
  cluster_running=0
  cluster_pending=0
  cluster_instances=0
else
  cluster_running="$(jq '.runningTasksCount // 0' <<< "$cluster_json")"
  cluster_pending="$(jq '.pendingTasksCount // 0' <<< "$cluster_json")"
  cluster_instances="$(jq '.registeredContainerInstancesCount // 0' <<< "$cluster_json")"
fi

vpcs="$(normalize_count vpcs "$vpcs")"
nats="$(normalize_count natGateways "$nats")"
instances="$(normalize_count ec2Instances "$instances")"
asgs="$(normalize_count autoScalingGroups "$asgs")"
albs="$(normalize_count loadBalancers "$albs")"
cluster_running="$(normalize_count ecsRunningTasks "$cluster_running")"
cluster_pending="$(normalize_count ecsPendingTasks "$cluster_pending")"
cluster_instances="$(normalize_count ecsContainerInstances "$cluster_instances")"
rds="$(normalize_count rdsInstances "$rds")"
proxies="$(normalize_count rdsProxies "$proxies")"
bootstrap_ecr="$(normalize_count bootstrapEcrRepositories "$bootstrap_ecr")"
buckets="$(normalize_count workloadBuckets "$buckets")"
cloudfront="$(normalize_count cloudFrontDistributions "$cloudfront")"
active_secrets="$(normalize_count activeSecrets "$active_secrets")"
flow_log_groups="$(normalize_count vpcFlowLogGroups "$flow_log_groups")"

jq -n \
  --argjson vpcs "$vpcs" \
  --argjson natGateways "$nats" \
  --argjson ec2Instances "$instances" \
  --argjson autoScalingGroups "$asgs" \
  --argjson loadBalancers "$albs" \
  --argjson ecsRunningTasks "$cluster_running" \
  --argjson ecsPendingTasks "$cluster_pending" \
  --argjson ecsContainerInstances "$cluster_instances" \
  --argjson rdsInstances "$rds" \
  --argjson rdsProxies "$proxies" \
  --argjson bootstrapEcrRepositories "$bootstrap_ecr" \
  --argjson workloadBuckets "$buckets" \
  --argjson cloudFrontDistributions "$cloudfront" \
  --argjson activeSecrets "$active_secrets" \
  --argjson vpcFlowLogGroups "$flow_log_groups" \
  '{status:"pending",remaining:{vpcs:$vpcs,natGateways:$natGateways,ec2Instances:$ec2Instances,autoScalingGroups:$autoScalingGroups,loadBalancers:$loadBalancers,ecsRunningTasks:$ecsRunningTasks,ecsPendingTasks:$ecsPendingTasks,ecsContainerInstances:$ecsContainerInstances,rdsInstances:$rdsInstances,rdsProxies:$rdsProxies,workloadBuckets:$workloadBuckets,cloudFrontDistributions:$cloudFrontDistributions,activeSecrets:$activeSecrets,vpcFlowLogGroups:$vpcFlowLogGroups},retainedPrerequisites:{ecrRepositories:$bootstrapEcrRepositories}} | .status=(if (([.remaining[]] | all(. == 0)) and .retainedPrerequisites.ecrRepositories == 1) then "passed" else "failed" end)' \
  > "$out_dir/aws-resource-audit.json"

jq -e '.status == "passed"' "$out_dir/aws-resource-audit.json" > /dev/null
echo "PASS aws-workload-resources-absent" >> "$out_dir/verification-status.txt"
