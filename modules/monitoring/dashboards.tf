resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-infrastructure-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "Requests" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", { stat = "Sum", label = "Target 4xx" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum", label = "Target 5xx" }]
          ]
          period = 300
          region = var.aws_region
          title  = "ALB Requests and Errors"
        }
        width  = 12
        height = 6
        x      = 0
        y      = 0
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Average", label = "Healthy" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { stat = "Average", label = "Unhealthy" }]
          ]
          period = 60
          region = var.aws_region
          title  = "ALB Target Health"
        }
        width  = 12
        height = 6
        x      = 12
        y      = 0
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name, { stat = "Average", label = "CPU %" }],
            [".", "MemoryUtilization", ".", ".", ".", ".", { stat = "Average", label = "Memory %" }]
          ]
          period = 300
          region = var.aws_region
          title  = "ECS Service Utilization"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 6
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_id, { stat = "Average", label = "CPU %" }],
            [".", "DatabaseConnections", ".", ".", { stat = "Average", label = "Connections" }],
            [".", "FreeableMemory", ".", ".", { stat = "Average", label = "Free memory" }]
          ]
          period = 300
          region = var.aws_region
          title  = "RDS Instance"
        }
        width  = 12
        height = 6
        x      = 12
        y      = 6
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", var.asg_name, { stat = "Average", label = "Desired" }],
            [".", "GroupInServiceInstances", ".", ".", { stat = "Average", label = "In service" }],
            [".", "GroupMinSize", ".", ".", { stat = "Average", label = "Min" }],
            [".", "GroupMaxSize", ".", ".", { stat = "Average", label = "Max" }]
          ]
          period = 300
          region = var.aws_region
          title  = "ECS Auto Scaling Group"
        }
        width  = 12
        height = 6
        x      = 0
        y      = 12
      },
      {
        type = "log"
        properties = {
          query         = "fields @timestamp, @message | stats count() by bin(5m)"
          region        = var.aws_region
          title         = "ECS Application Log Volume"
          logGroupNames = [var.ecs_log_group_name]
        }
        width  = 12
        height = 6
        x      = 12
        y      = 12
      },
      {
        type = "log"
        properties = {
          query         = "fields srcaddr, dstport, action | stats count() as requests by srcaddr, dstport, action | sort requests desc | limit 20"
          region        = var.aws_region
          title         = "VPC Flow Logs - Top Traffic"
          logGroupNames = [var.vpc_flow_log_group_name]
        }
        width  = 24
        height = 6
        x      = 0
        y      = 18
      }
    ]
  })
}

resource "aws_cloudwatch_dashboard" "performance" {
  dashboard_name = "${var.project_name}-performance-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "p50", label = "p50" }],
            [".", ".", ".", ".", ".", ".", { stat = "p90", label = "p90" }],
            [".", ".", ".", ".", ".", ".", { stat = "p99", label = "p99" }]
          ]
          period = 300
          region = var.aws_region
          title  = "ALB Target Response Time"
        }
        width  = 12
        height = 6
        x      = 0
        y      = 0
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", var.rds_instance_id, { stat = "Average", label = "Read latency" }],
            [".", "WriteLatency", ".", ".", { stat = "Average", label = "Write latency" }],
            [".", "ReadIOPS", ".", ".", { stat = "Average", label = "Read IOPS" }],
            [".", "WriteIOPS", ".", ".", { stat = "Average", label = "Write IOPS" }]
          ]
          period = 300
          region = var.aws_region
          title  = "RDS Latency and IOPS"
        }
        width  = 12
        height = 6
        x      = 12
        y      = 0
      }
    ]
  })
}

resource "aws_cloudwatch_dashboard" "security" {
  dashboard_name = "${var.project_name}-security-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = var.waf_web_acl_name != "" ? [
            ["AWS/WAFV2", "BlockedRequests", "WebACL", var.waf_web_acl_name, "Rule", "ALL", "Region", var.aws_region, { stat = "Sum", label = "Blocked" }],
            [".", "AllowedRequests", ".", ".", ".", ".", ".", ".", { stat = "Sum", label = "Allowed" }]
          ] : []
          period = 300
          region = var.aws_region
          title  = "WAF Request Status"
        }
        width  = 12
        height = 6
        x      = 0
        y      = 0
      },
      {
        type = "log"
        properties = {
          query         = "fields action, terminatingRuleId | stats count() by action, terminatingRuleId | sort count() desc"
          region        = var.aws_region
          title         = "WAF Triggered Rules"
          logGroupNames = var.waf_log_group_name != "" ? [var.waf_log_group_name] : []
        }
        width  = 12
        height = 6
        x      = 12
        y      = 0
      },
      {
        type = "log"
        properties = {
          query         = "fields srcaddr, dstaddr, dstport, action | filter action = 'REJECT' | stats count() as rejected by srcaddr, dstaddr, dstport | sort rejected desc | limit 20"
          region        = var.aws_region
          title         = "VPC Flow Logs - Rejected Connections"
          logGroupNames = [var.vpc_flow_log_group_name]
        }
        width  = 24
        height = 6
        x      = 0
        y      = 6
      }
    ]
  })
}
