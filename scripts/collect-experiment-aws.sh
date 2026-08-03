#!/usr/bin/env bash
set -euo pipefail

tf_dir="${1:-env/dev}"
start_time="${2:?start time is required}"
end_time="${3:?end time is required}"
out_dir="${4:-experiment-evidence/aws}"

mkdir -p "$out_dir"
cluster="$(terraform -chdir="$tf_dir" output -raw ecs_cluster_name)"
service="$(terraform -chdir="$tf_dir" output -raw ecs_service_name)"
asg="$(terraform -chdir="$tf_dir" output -raw asg_name)"
rds="$(terraform -chdir="$tf_dir" output -raw rds_instance_id)"
proxy="$(terraform -chdir="$tf_dir" output -raw rds_proxy_id)"
alb_suffix="$(terraform -chdir="$tf_dir" output -raw alb_arn_suffix)"
tg_arn="$(terraform -chdir="$tf_dir" output -raw target_group_arn)"
tg_suffix="$(terraform -chdir="$tf_dir" output -raw target_group_arn_suffix)"
waf="$(terraform -chdir="$tf_dir" output -raw waf_web_acl_name)"
ecs_logs="$(terraform -chdir="$tf_dir" output -raw ecs_log_group_name)"
waf_logs="$(terraform -chdir="$tf_dir" output -raw waf_log_group_name)"

jq -n \
  --arg cluster "$cluster" \
  --arg service "$service" \
  --arg asg "$asg" \
  --arg rds "$rds" \
  --arg alb "$alb_suffix" \
  --arg tg "$tg_suffix" \
  --arg waf "$waf" \
  --arg region "$AWS_REGION" \
  '[
    {Id:"albrequests",MetricStat:{Metric:{Namespace:"AWS/ApplicationELB",MetricName:"RequestCount",Dimensions:[{Name:"LoadBalancer",Value:$alb}]},Period:60,Stat:"Sum"},ReturnData:true},
    {Id:"albp95",MetricStat:{Metric:{Namespace:"AWS/ApplicationELB",MetricName:"TargetResponseTime",Dimensions:[{Name:"LoadBalancer",Value:$alb},{Name:"TargetGroup",Value:$tg}]},Period:60,Stat:"p95"},ReturnData:true},
    {Id:"alb4xx",MetricStat:{Metric:{Namespace:"AWS/ApplicationELB",MetricName:"HTTPCode_Target_4XX_Count",Dimensions:[{Name:"LoadBalancer",Value:$alb},{Name:"TargetGroup",Value:$tg}]},Period:60,Stat:"Sum"},ReturnData:true},
    {Id:"alb5xx",MetricStat:{Metric:{Namespace:"AWS/ApplicationELB",MetricName:"HTTPCode_Target_5XX_Count",Dimensions:[{Name:"LoadBalancer",Value:$alb},{Name:"TargetGroup",Value:$tg}]},Period:60,Stat:"Sum"},ReturnData:true},
    {Id:"ecscpu",MetricStat:{Metric:{Namespace:"AWS/ECS",MetricName:"CPUUtilization",Dimensions:[{Name:"ClusterName",Value:$cluster},{Name:"ServiceName",Value:$service}]},Period:60,Stat:"Average"},ReturnData:true},
    {Id:"ecsmemory",MetricStat:{Metric:{Namespace:"AWS/ECS",MetricName:"MemoryUtilization",Dimensions:[{Name:"ClusterName",Value:$cluster},{Name:"ServiceName",Value:$service}]},Period:60,Stat:"Average"},ReturnData:true},
    {Id:"asginservice",MetricStat:{Metric:{Namespace:"AWS/AutoScaling",MetricName:"GroupInServiceInstances",Dimensions:[{Name:"AutoScalingGroupName",Value:$asg}]},Period:60,Stat:"Average"},ReturnData:true},
    {Id:"asgdesired",MetricStat:{Metric:{Namespace:"AWS/AutoScaling",MetricName:"GroupDesiredCapacity",Dimensions:[{Name:"AutoScalingGroupName",Value:$asg}]},Period:60,Stat:"Average"},ReturnData:true},
    {Id:"asgpending",MetricStat:{Metric:{Namespace:"AWS/AutoScaling",MetricName:"GroupPendingInstances",Dimensions:[{Name:"AutoScalingGroupName",Value:$asg}]},Period:60,Stat:"Average"},ReturnData:true},
    {Id:"asgterminating",MetricStat:{Metric:{Namespace:"AWS/AutoScaling",MetricName:"GroupTerminatingInstances",Dimensions:[{Name:"AutoScalingGroupName",Value:$asg}]},Period:60,Stat:"Average"},ReturnData:true},
    {Id:"rdscpu",MetricStat:{Metric:{Namespace:"AWS/RDS",MetricName:"CPUUtilization",Dimensions:[{Name:"DBInstanceIdentifier",Value:$rds}]},Period:60,Stat:"Average"},ReturnData:true},
    {Id:"rdsconnections",MetricStat:{Metric:{Namespace:"AWS/RDS",MetricName:"DatabaseConnections",Dimensions:[{Name:"DBInstanceIdentifier",Value:$rds}]},Period:60,Stat:"Average"},ReturnData:true},
    {Id:"wafallowed",MetricStat:{Metric:{Namespace:"AWS/WAFV2",MetricName:"AllowedRequests",Dimensions:[{Name:"WebACL",Value:$waf},{Name:"Rule",Value:"ALL"},{Name:"Region",Value:$region}]},Period:60,Stat:"Sum"},ReturnData:true},
    {Id:"wafblocked",MetricStat:{Metric:{Namespace:"AWS/WAFV2",MetricName:"BlockedRequests",Dimensions:[{Name:"WebACL",Value:$waf},{Name:"Rule",Value:"ALL"},{Name:"Region",Value:$region}]},Period:60,Stat:"Sum"},ReturnData:true},
    {Id:"wafrateblocked",MetricStat:{Metric:{Namespace:"AWS/WAFV2",MetricName:"BlockedRequests",Dimensions:[{Name:"WebACL",Value:$waf},{Name:"Rule",Value:"ExperimentRateLimit"},{Name:"Region",Value:$region}]},Period:60,Stat:"Sum"},ReturnData:true}
  ]' > "$out_dir/metric-queries.json"

aws cloudwatch get-metric-data \
  --metric-data-queries "file://$out_dir/metric-queries.json" \
  --start-time "$start_time" \
  --end-time "$end_time" \
  --scan-by TimestampAscending > "$out_dir/cloudwatch-metrics.json"

aws ecs describe-services --cluster "$cluster" --services "$service" > "$out_dir/ecs-service.json"
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$asg" > "$out_dir/asg.json"
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name "$asg" --max-records 100 > "$out_dir/asg-activities.json"
aws application-autoscaling describe-scaling-activities \
  --service-namespace ecs \
  --resource-id "service/$cluster/$service" \
  --max-results 50 > "$out_dir/ecs-scaling-activities.json"
aws elbv2 describe-target-health --target-group-arn "$tg_arn" > "$out_dir/target-health.json"
aws rds describe-db-instances --db-instance-identifier "$rds" > "$out_dir/rds.json"
aws rds describe-db-proxy-targets --db-proxy-name "$proxy" > "$out_dir/rds-proxy-targets.json"
aws cloudwatch describe-alarms --alarm-name-prefix "${cluster%-cluster}" > "$out_dir/alarms.json"

start_ms="$(( $(date -d "$start_time" +%s) * 1000 ))"
end_ms="$(( $(date -d "$end_time" +%s) * 1000 ))"
aws logs filter-log-events \
  --log-group-name "$ecs_logs" \
  --start-time "$start_ms" \
  --end-time "$end_ms" \
  --filter-pattern "?ERROR ?Error ?error ?EROFS" \
  --limit 100 > "$out_dir/application-errors.json"
if [ -n "$waf_logs" ] && [ "$waf_logs" != "null" ]; then
  aws logs filter-log-events \
    --log-group-name "$waf_logs" \
    --start-time "$start_ms" \
    --end-time "$end_ms" \
    --limit 100 > "$out_dir/waf-events.json"
fi

required_series='["albrequests","albp95","ecscpu","ecsmemory","asginservice","asgdesired","rdscpu","rdsconnections","wafallowed"]'
jq --argjson required "$required_series" '
  . + {
    requiredSeries: $required,
    populatedSeries: [.MetricDataResults[] | select(.StatusCode == "Complete" and (.Values | length) > 0) | .Id]
  }
' "$out_dir/cloudwatch-metrics.json" > "$out_dir/cloudwatch-metrics.normalized.json"
mv "$out_dir/cloudwatch-metrics.normalized.json" "$out_dir/cloudwatch-metrics.json"

jq -n \
  --arg start "$start_time" \
  --arg end "$end_time" \
  --arg region "$AWS_REGION" \
  '{status:"collected", startTime:$start, endTime:$end, region:$region, periodSeconds:60}' \
  > "$out_dir/collection-window.json"
