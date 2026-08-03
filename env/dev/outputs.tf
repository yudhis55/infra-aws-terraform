output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.ecs.alb_dns_name
}

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = module.ecs.alb_arn
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix used by CloudWatch metric dimensions"
  value       = module.ecs.alb_arn_suffix
}

output "target_group_arn" {
  description = "ECS target group ARN"
  value       = module.ecs.target_group_arn
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix used by CloudWatch metric dimensions"
  value       = module.ecs.target_group_arn_suffix
}

output "application_url" {
  description = "Application URL from domain when configured, otherwise ALB URL"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${module.ecs.alb_dns_name}"
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.ecs_service_name
}

output "ecs_log_group_name" {
  description = "CloudWatch log group receiving application container logs"
  value       = module.ecs.cloudwatch_log_group_name
}

output "asg_name" {
  description = "ECS Auto Scaling Group name"
  value       = module.ecs.asg_name
}

output "rds_instance_id" {
  description = "RDS instance identifier"
  value       = module.rds.rds_instance_id
}

output "rds_proxy_endpoint" {
  description = "RDS Proxy endpoint used by the application"
  value       = module.rds.rds_proxy_endpoint
}

output "rds_proxy_id" {
  description = "RDS Proxy identifier"
  value       = module.rds.rds_proxy_id
}

output "s3_public_bucket_name" {
  description = "Private S3 origin bucket for public media"
  value       = module.storage.public_bucket_id
}

output "s3_private_bucket_name" {
  description = "S3 bucket for private payment and verification documents"
  value       = module.storage.private_bucket_id
}

output "cloudfront_media_url" {
  description = "CloudFront base URL for public media"
  value       = module.cdn.public_base_url
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for public media"
  value       = module.cdn.distribution_id
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = module.security.waf_web_acl_arn
}

output "waf_web_acl_name" {
  description = "WAF Web ACL name used by CloudWatch metric dimensions"
  value       = module.security.waf_web_acl_name
}

output "waf_log_group_name" {
  description = "CloudWatch log group receiving WAF request logs"
  value       = module.security.waf_log_group_name
}

output "vpc_flow_log_group_name" {
  description = "CloudWatch log group receiving VPC Flow Logs"
  value       = module.security.vpc_flow_logs_log_group
}

output "monitoring_dashboard_names" {
  description = "CloudWatch dashboards used as experiment monitoring evidence"
  value = {
    infrastructure = module.monitoring.infrastructure_dashboard_name
    performance    = module.monitoring.performance_dashboard_name
    security       = module.monitoring.security_dashboard_name
  }
}

output "rds_instance_address" {
  description = "Private RDS instance hostname used only by the isolation test allowlist"
  value       = module.rds.rds_instance_address
}

output "experiment_mode" {
  description = "Active opt-in experiment mode"
  value       = var.experiment_mode
}

output "experiment_agent_instance_id" {
  description = "Private SSM agent ID, or null when experiments are disabled"
  value       = module.experiment.instance_id
}

output "experiment_agent_private_ip" {
  description = "Private agent IP used for Flow Log correlation"
  value       = module.experiment.private_ip
}

output "experiment_source_ipv4" {
  description = "Public /32 source used by temporary WAF controls"
  value       = local.experiment_enabled ? local.experiment_source_ipv4 : null
}

output "experiment_drift_role_arn" {
  description = "Scoped role for the single-tag drift test"
  value       = module.experiment.drift_role_arn
}

output "experiment_drift_target_arn" {
  description = "Only resource authorized for the drift mutation"
  value       = module.experiment.drift_target_arn
}
