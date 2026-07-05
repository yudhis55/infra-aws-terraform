output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.ecs.alb_dns_name
}

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = module.ecs.alb_arn
}

output "target_group_arn" {
  description = "ECS target group ARN"
  value       = module.ecs.target_group_arn
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

output "asg_name" {
  description = "ECS Auto Scaling Group name"
  value       = module.ecs.asg_name
}

output "ecr_repository_url" {
  description = "ECR repository URL used by the application pipeline"
  value       = module.ecr.repository_url
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

output "s3_bucket_name" {
  description = "Private application upload bucket"
  value       = module.storage.bucket_id
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
