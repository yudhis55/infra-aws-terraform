output "sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "SNS topic name for alarm notifications"
  value       = aws_sns_topic.alerts.name
}

output "infrastructure_dashboard_name" {
  description = "CloudWatch dashboard name for infrastructure overview"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "performance_dashboard_name" {
  description = "CloudWatch dashboard name for performance deep dive"
  value       = aws_cloudwatch_dashboard.performance.dashboard_name
}

output "security_dashboard_name" {
  description = "CloudWatch dashboard name for security monitoring"
  value       = aws_cloudwatch_dashboard.security.dashboard_name
}

output "alarms_created" {
  description = "List of CloudWatch alarms created for monitoring"
  value = {
    alb_alarms = [
      aws_cloudwatch_metric_alarm.alb_target_health.alarm_name,
      aws_cloudwatch_metric_alarm.alb_target_response_time.alarm_name,
      aws_cloudwatch_metric_alarm.alb_http_5xx.alarm_name
    ]
    ecs_alarms = [
      aws_cloudwatch_metric_alarm.ecs_running_tasks.alarm_name,
      aws_cloudwatch_metric_alarm.ecs_cpu_utilization.alarm_name,
      aws_cloudwatch_metric_alarm.ecs_memory_utilization.alarm_name
    ]
    rds_alarms = [
      aws_cloudwatch_metric_alarm.rds_cpu_utilization.alarm_name,
      aws_cloudwatch_metric_alarm.rds_database_connections.alarm_name,
      aws_cloudwatch_metric_alarm.rds_free_storage_space.alarm_name,
      aws_cloudwatch_metric_alarm.rds_read_latency.alarm_name,
      aws_cloudwatch_metric_alarm.rds_write_latency.alarm_name
    ]
    waf_alarms = [
      for alarm in aws_cloudwatch_metric_alarm.waf_blocked_requests_spike : alarm.alarm_name
    ]
    asg_alarms = [
      aws_cloudwatch_metric_alarm.asg_insufficient_capacity.alarm_name
    ]
    application_alarms = [
      aws_cloudwatch_metric_alarm.application_errors.alarm_name
    ]
  }
}

output "log_metric_filters_created" {
  description = "Log metric filters for custom monitoring"
  value = {
    application_errors = aws_cloudwatch_log_metric_filter.app_errors.name
  }
}
