output "public_subnets" {
  value = aws_subnet.public[*].id
}

output "private_app_subnets" {
  value       = aws_subnet.private_app[*].id
  description = "Private application tier subnet IDs (ECS, EC2)"
}

output "private_data_subnets" {
  value       = aws_subnet.private_data[*].id
  description = "Private data tier subnet IDs (RDS, Databases)"
}

output "private_subnets" {
  value       = aws_subnet.private_app[*].id
  description = "Backward compatibility: returns private app subnet IDs"
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "internet_gateway_id" {
  value       = aws_internet_gateway.this.id
  description = "Internet Gateway ID for outbound internet access"
}
