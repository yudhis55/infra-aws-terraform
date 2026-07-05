variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications (leave empty to disable)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ecs_min_size" {
  description = "Minimum number of ECS instances (for alarm thresholds)"
  type        = number
  default     = 2
}

variable "ecs_cluster_name" {
  description = "ECS cluster name for CloudWatch alarm dimensions"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name for CloudWatch alarm dimensions"
  type        = string
}

variable "asg_name" {
  description = "Auto Scaling Group name for CloudWatch alarm dimensions"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch ApplicationELB dimensions"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix for CloudWatch ApplicationELB dimensions"
  type        = string
}

variable "rds_instance_id" {
  description = "RDS DB instance identifier for CloudWatch alarm dimensions"
  type        = string
}

variable "ecs_log_group_name" {
  description = "ECS application CloudWatch log group name"
  type        = string
}

variable "waf_web_acl_name" {
  description = "WAF Web ACL name for CloudWatch WAFV2 dimensions. Empty disables WAF-specific alarms."
  type        = string
  default     = ""
}

variable "waf_log_group_name" {
  description = "CloudWatch log group name that receives WAF logs"
  type        = string
  default     = ""
}

variable "vpc_flow_log_group_name" {
  description = "CloudWatch log group name that receives VPC Flow Logs"
  type        = string
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for lower granularity metrics"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7

  validation {
    condition     = var.log_retention_days >= 1 && var.log_retention_days <= 3653
    error_message = "Log retention must be between 1 and 3653 days."
  }
}
