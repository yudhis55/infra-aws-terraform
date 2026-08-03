#!/usr/bin/env bash
set -euo pipefail

project="${1:-eepistore}"
environment="${2:-dev}"
out_dir="${3:-destroy-evidence}"
mkdir -p "$out_dir"

vpcs="$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$project-$environment-vpc" --query 'length(Vpcs)' --output json)"
nats="$(aws ec2 describe-nat-gateways --filter "Name=tag:Name,Values=$project-$environment-nat-*" "Name=state,Values=pending,available,deleting,failed" --query 'length(NatGateways)' --output json)"
instances="$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$project-ecs-instance,$project-$environment-experiment-agent" "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down" --query 'length(Reservations[].Instances[])' --output json)"
asgs="$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$project-asg" --query 'length(AutoScalingGroups)' --output json)"
albs="$(aws elbv2 describe-load-balancers --names "$project-alb" --query 'length(LoadBalancers)' --output json 2>/dev/null || echo 0)"
rds="$(aws rds describe-db-instances --db-instance-identifier "$project-$environment-db" --query 'length(DBInstances)' --output json 2>/dev/null || echo 0)"
proxies="$(aws rds describe-db-proxies --db-proxy-name "$project-$environment-proxy" --query 'length(DBProxies)' --output json 2>/dev/null || echo 0)"
bootstrap_ecr="$(aws ecr describe-repositories --repository-names "$project-repo" --query 'length(repositories)' --output json 2>/dev/null || echo 0)"
buckets="$(aws s3api list-buckets --query "length(Buckets[?starts_with(Name, '$project-$environment-public-media-') || starts_with(Name, '$project-$environment-private-documents-') || starts_with(Name, '$project-$environment-alb-logs-')])" --output json)"
cloudfront="$(aws cloudfront list-distributions --query "length(DistributionList.Items[?Aliases.Items && contains(Aliases.Items, 'media.eepistore.web.id')])" --output json)"
active_secrets="$(aws secretsmanager list-secrets --include-planned-deletion --filters Key=name,Values="$project-$environment-app-secrets" --query 'length(SecretList[?DeletedDate == null])' --output json)"

cluster_json="$(aws ecs describe-clusters --clusters "$project-cluster" --include ATTACHMENTS --query 'clusters[0]' --output json)"
if [ "$cluster_json" = null ]; then
  cluster_running=0
  cluster_pending=0
  cluster_instances=0
else
  cluster_running="$(jq '.runningTasksCount // 0' <<< "$cluster_json")"
  cluster_pending="$(jq '.pendingTasksCount // 0' <<< "$cluster_json")"
  cluster_instances="$(jq '.registeredContainerInstancesCount // 0' <<< "$cluster_json")"
fi

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
  '{status:"pending",remaining:{vpcs:$vpcs,natGateways:$natGateways,ec2Instances:$ec2Instances,autoScalingGroups:$autoScalingGroups,loadBalancers:$loadBalancers,ecsRunningTasks:$ecsRunningTasks,ecsPendingTasks:$ecsPendingTasks,ecsContainerInstances:$ecsContainerInstances,rdsInstances:$rdsInstances,rdsProxies:$rdsProxies,workloadBuckets:$workloadBuckets,cloudFrontDistributions:$cloudFrontDistributions,activeSecrets:$activeSecrets},retainedPrerequisites:{ecrRepositories:$bootstrapEcrRepositories}} | .status=(if (([.remaining[]] | all(. == 0)) and .retainedPrerequisites.ecrRepositories == 1) then "passed" else "failed" end)' \
  > "$out_dir/aws-resource-audit.json"

jq -e '.status == "passed"' "$out_dir/aws-resource-audit.json" > /dev/null
echo "PASS aws-workload-resources-absent" >> "$out_dir/verification-status.txt"
