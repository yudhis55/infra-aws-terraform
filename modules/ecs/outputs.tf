output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer for CloudWatch dimensions"
  value       = aws_lb.main.arn_suffix
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "ecs_service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.app.id
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.ecs.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.ecs.arn
}

output "target_group_arn" {
  description = "ARN of the target group for EC2 instances"
  value       = aws_lb_target_group.ecs_ec2.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group for CloudWatch dimensions"
  value       = aws_lb_target_group.ecs_ec2.arn_suffix
}

output "target_group_name" {
  description = "Name of the target group for EC2 instances"
  value       = aws_lb_target_group.ecs_ec2.name
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group for ECS"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of CloudWatch log group for ECS"
  value       = aws_cloudwatch_log_group.ecs.arn
}

output "alb_logs_bucket_name" {
  description = "S3 bucket name for ALB access logs"
  value       = aws_s3_bucket.alb_logs.id
}

output "alb_logs_bucket_arn" {
  description = "S3 bucket ARN for ALB access logs"
  value       = aws_s3_bucket.alb_logs.arn
}

output "launch_template_id" {
  description = "ID of the EC2 launch template"
  value       = aws_launch_template.ecs.id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.ecs.latest_version
}

output "acm_certificate_arn" {
  description = "ARN of ACM certificate for HTTPS"
  value       = var.enable_https ? var.acm_certificate_arn : null
}

output "acm_certificate_domain" {
  description = "ACM certificate domain is managed outside the ECS module"
  value       = null
}
