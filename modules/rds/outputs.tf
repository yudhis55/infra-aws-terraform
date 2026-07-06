# RDS Instance Outputs
output "rds_instance_id" {
  value       = aws_db_instance.main.identifier
  description = "RDS instance identifier"
}

output "rds_instance_endpoint" {
  value       = aws_db_instance.main.endpoint
  description = "RDS instance endpoint (host:port)"
}

output "rds_instance_address" {
  value       = aws_db_instance.main.address
  description = "RDS instance hostname"
}

output "rds_instance_port" {
  value       = aws_db_instance.main.port
  description = "RDS instance port"
}

output "rds_instance_arn" {
  value       = aws_db_instance.main.arn
  description = "RDS instance ARN"
}

output "rds_database_name" {
  value       = aws_db_instance.main.db_name
  description = "Database name"
}

output "rds_master_username" {
  value       = aws_db_instance.main.username
  description = "Master username (sensitive)"
  sensitive   = true
}

# DB Subnet Group Outputs
output "db_subnet_group_id" {
  value       = aws_db_subnet_group.main.id
  description = "DB subnet group identifier"
}

output "db_subnet_group_arn" {
  value       = aws_db_subnet_group.main.arn
  description = "DB subnet group ARN"
}

# Encryption Outputs
output "rds_kms_key_id" {
  value       = aws_kms_key.rds.key_id
  description = "KMS key ID for RDS encryption"
}

output "rds_kms_key_arn" {
  value       = aws_kms_key.rds.arn
  description = "KMS key ARN for RDS encryption"
}

# RDS Proxy Outputs
output "rds_proxy_endpoint" {
  value       = var.enable_rds_proxy ? aws_db_proxy.main[0].endpoint : null
  description = "RDS Proxy endpoint (use this for application connections)"
}

output "rds_proxy_arn" {
  value       = var.enable_rds_proxy ? aws_db_proxy.main[0].arn : null
  description = "RDS Proxy ARN"
}

output "rds_proxy_id" {
  value       = var.enable_rds_proxy ? aws_db_proxy.main[0].id : null
  description = "RDS Proxy identifier"
}

output "rds_proxy_enabled" {
  value       = var.enable_rds_proxy
  description = "Whether RDS Proxy is enabled"
}

# Secrets Manager Outputs
output "rds_secrets_manager_secret_arn" {
  value       = var.secrets_manager_secret_arn != "" ? var.secrets_manager_secret_arn : (var.enable_rds_proxy ? aws_secretsmanager_secret.db_credentials[0].arn : null)
  description = "Secrets Manager secret ARN for RDS credentials"
}

output "rds_secrets_manager_secret_name" {
  value       = var.secrets_manager_secret_arn == "" && var.enable_rds_proxy ? aws_secretsmanager_secret.db_credentials[0].name : null
  description = "Secrets Manager secret name for RDS credentials"
}

# Security Group Outputs
output "rds_security_group_id" {
  value       = var.rds_security_group_id
  description = "RDS instance security group ID (passed from networking)"
}

output "rds_proxy_security_group_id" {
  value       = var.enable_rds_proxy ? aws_security_group.proxy.id : null
  description = "RDS Proxy security group ID"
}

# Connection Information for Applications
output "connection_info_via_proxy" {
  value = var.enable_rds_proxy ? {
    host       = aws_db_proxy.main[0].endpoint
    port       = 5432
    database   = var.db_name
    username   = var.db_username
    secret_arn = var.secrets_manager_secret_arn != "" ? var.secrets_manager_secret_arn : aws_secretsmanager_secret.db_credentials[0].arn
  } : null
  description = "Connection information for applications using RDS Proxy"
  sensitive   = true
}

output "connection_info_direct" {
  value = {
    host       = aws_db_instance.main.address
    port       = aws_db_instance.main.port
    database   = var.db_name
    username   = var.db_username
    secret_arn = var.secrets_manager_secret_arn != "" ? var.secrets_manager_secret_arn : aws_secretsmanager_secret.db_credentials[0].arn
  }
  description = "Direct connection information to RDS (bypass proxy)"
  sensitive   = true
}

# Parameter Group Output
output "db_parameter_group_id" {
  value       = aws_db_parameter_group.main.id
  description = "DB parameter group identifier"
}

output "monitoring_role_arn" {
  value       = aws_iam_role.rds_monitoring.arn
  description = "IAM role ARN for RDS monitoring"
}
