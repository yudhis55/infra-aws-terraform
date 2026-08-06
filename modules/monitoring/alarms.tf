# ==================== SNS Topic untuk Alarm Notifications ====================
# Untuk mengirim alarm notifications via email atau SMS

resource "aws_sns_topic" "alerts" {
  name_prefix       = "${var.project_name}-alerts-"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name = "${var.project_name}-alerts"
  }
}

resource "aws_sns_topic_subscription" "alerts_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ==================== ALB Alarms ====================
# Monitor ALB health, response times, and errors

resource "aws_cloudwatch_metric_alarm" "alb_target_health" {
  alarm_name          = "${var.project_name}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Alert when ALB has unhealthy targets"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  tags = {
    Name = "${var.project_name}-alb-health"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "${var.project_name}-alb-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1.0 # 1 second
  alarm_description   = "Alert when ALB response time exceeds 1 second"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  tags = {
    Name = "${var.project_name}-alb-response-time"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_http_5xx" {
  alarm_name          = "${var.project_name}-alb-http-5xx-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert when 5xx errors exceed 10 in 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = {
    Name = "${var.project_name}-alb-5xx"
  }
}

# ==================== ECS Alarms ====================
# Monitor ECS cluster and service health

resource "aws_cloudwatch_metric_alarm" "ecs_running_tasks" {
  alarm_name          = "${var.project_name}-ecs-insufficient-running-tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = var.ecs_min_running_tasks
  alarm_description   = "Alert when running ECS tasks fall below minimum"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = var.ecs_service_name
    ClusterName = var.ecs_cluster_name
  }

  tags = {
    Name = "${var.project_name}-ecs-tasks"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization" {
  alarm_name          = "${var.project_name}-ecs-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80 # 80% CPU
  alarm_description   = "Alert when ECS CPU utilization exceeds 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = var.ecs_service_name
    ClusterName = var.ecs_cluster_name
  }

  tags = {
    Name = "${var.project_name}-ecs-cpu"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization" {
  alarm_name          = "${var.project_name}-ecs-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85 # 85% Memory
  alarm_description   = "Alert when ECS memory utilization exceeds 85%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = var.ecs_service_name
    ClusterName = var.ecs_cluster_name
  }

  tags = {
    Name = "${var.project_name}-ecs-memory"
  }
}

# ==================== RDS Alarms ====================
# Monitor database health, connections, and performance

resource "aws_cloudwatch_metric_alarm" "rds_cpu_utilization" {
  alarm_name          = "${var.project_name}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80 # 80% CPU
  alarm_description   = "Alert when RDS CPU exceeds 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = {
    Name = "${var.project_name}-rds-cpu"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_database_connections" {
  alarm_name          = "${var.project_name}-rds-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80 # 80% of max connections
  alarm_description   = "Alert when DB connections exceed 80 (typical max ~100)"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = {
    Name = "${var.project_name}-rds-connections"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage_space" {
  alarm_name          = "${var.project_name}-rds-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2147483648 # 2GB in bytes
  alarm_description   = "Alert when RDS free storage falls below 2GB"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = {
    Name = "${var.project_name}-rds-storage"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_read_latency" {
  alarm_name          = "${var.project_name}-rds-high-read-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ReadLatency"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 0.005 # CloudWatch reports RDS latency in seconds.
  alarm_description   = "Alert when RDS read latency exceeds 5ms"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = {
    Name = "${var.project_name}-rds-read-latency"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_write_latency" {
  alarm_name          = "${var.project_name}-rds-high-write-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "WriteLatency"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 0.010 # CloudWatch reports RDS latency in seconds.
  alarm_description   = "Alert when RDS write latency exceeds 10ms"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = {
    Name = "${var.project_name}-rds-write-latency"
  }
}

# ==================== WAF Alarms ====================
# Monitor WAF blocking activity and anomalies

resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests_spike" {
  count               = var.waf_metric_name != "" ? 1 : 0
  alarm_name          = "${var.project_name}-waf-blocked-requests-spike"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 100 # 100 blocked requests in 5 minutes
  alarm_description   = "Alert when WAF blocks exceed 100 requests in 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    WebACL = var.waf_metric_name
    Rule   = "ALL"
    Region = var.aws_region
  }

  tags = {
    Name = "${var.project_name}-waf-blocked"
  }
}

# ==================== Auto Scaling Group Alarms ====================
# Monitor ASG capacity and scaling activity

resource "aws_cloudwatch_metric_alarm" "asg_insufficient_capacity" {
  alarm_name          = "${var.project_name}-asg-insufficient-capacity"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "GroupInServiceInstances"
  namespace           = "AWS/AutoScaling"
  period              = 300
  statistic           = "Average"
  threshold           = var.asg_min_size
  alarm_description   = "Alert when ASG instances fall below minimum"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  tags = {
    Name = "${var.project_name}-asg-capacity"
  }
}

# ==================== Custom Log-based Alarms ====================
# Monitor application logs for errors

resource "aws_cloudwatch_log_group" "error_metric_filter" {
  name              = "/aws/lambda/${var.project_name}-error-tracker"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-error-tracking"
  }
}

resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  name           = "${var.project_name}-app-errors-filter"
  log_group_name = var.ecs_log_group_name
  pattern        = "[time, request_id, level = ERROR*, ...]"

  metric_transformation {
    name      = "${var.project_name}-ApplicationErrors"
    namespace = "CustomMetrics/${var.project_name}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "application_errors" {
  alarm_name          = "${var.project_name}-app-high-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "${var.project_name}-ApplicationErrors"
  namespace           = "CustomMetrics/${var.project_name}"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert when application error count exceeds 10 in 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.project_name}-app-errors"
  }
}
