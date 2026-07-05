# Consolidated outputs for networking module

output "nat_gateway_ids" {
  value       = aws_nat_gateway.nat[*].id
  description = "IDs of NAT Gateways (one per AZ)"
}

output "elastic_ip_ids" {
  value       = aws_eip.nat[*].id
  description = "Elastic IP IDs associated with NAT Gateways"
}

output "nat_gateway_public_ips" {
  value       = aws_eip.nat[*].public_ip
  description = "Public IP addresses of NAT Gateways"
}

output "private_app_route_table_ids" {
  value       = aws_route_table.private_app[*].id
  description = "Route table IDs for private app tier (per AZ)"
}

output "private_data_route_table_id" {
  value       = aws_route_table.private_data.id
  description = "Route table ID for private data tier"
}

output "vpc_endpoint_sg_id" {
  value       = aws_security_group.vpc_endpoint_sg.id
  description = "Security group ID for VPC Endpoints"
}

output "s3_endpoint_id" {
  value       = aws_vpc_endpoint.s3.id
  description = "S3 Gateway Endpoint ID"
}

output "ecr_api_endpoint_id" {
  value       = aws_vpc_endpoint.ecr_api.id
  description = "ECR API Interface Endpoint ID"
}

output "ecr_dkr_endpoint_id" {
  value       = aws_vpc_endpoint.ecr_dkr.id
  description = "ECR DKR Interface Endpoint ID"
}

output "secrets_manager_endpoint_id" {
  value       = aws_vpc_endpoint.secrets_manager.id
  description = "Secrets Manager Interface Endpoint ID"
}

output "cloudwatch_logs_endpoint_id" {
  value       = aws_vpc_endpoint.cloudwatch_logs.id
  description = "CloudWatch Logs Interface Endpoint ID"
}

output "alb_security_group_id" {
  value       = aws_security_group.alb.id
  description = "Security group ID for Application Load Balancer"
}

output "ecs_security_group_id" {
  value       = aws_security_group.ecs.id
  description = "Security group ID for ECS tasks and instances"
}

output "rds_security_group_id" {
  value       = aws_security_group.rds.id
  description = "Security group ID for RDS database"
}

output "alb_security_group_arn" {
  value       = aws_security_group.alb.arn
  description = "Security group ARN for Application Load Balancer"
}

output "ecs_security_group_arn" {
  value       = aws_security_group.ecs.arn
  description = "Security group ARN for ECS"
}

output "rds_security_group_arn" {
  value       = aws_security_group.rds.arn
  description = "Security group ARN for RDS"
}
