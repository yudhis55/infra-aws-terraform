variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "ecommercedb"
}

variable "db_username" {
  description = "Master username for RDS database"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.3"
}

variable "db_instance_class" {
  description = "RDS instance class (e.g., db.t3.small, db.t3.medium)"
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_storage_type" {
  description = "Storage type (gp2, gp3, io1, io2)"
  type        = string
  default     = "gp3"
}

variable "db_iops" {
  description = "IOPS for gp3/io1/io2 storage"
  type        = number
  default     = 3000
}

variable "db_storage_throughput" {
  description = "Storage throughput for gp3 in MB/s (125-1000)"
  type        = number
  default     = 125
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy (recommended: false for production)"
  type        = bool
  default     = false
}

variable "enable_encryption" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "private_data_subnet_ids" {
  description = "List of private data tier subnet IDs for DB subnet group"
  type        = list(string)
  validation {
    condition     = length(var.private_data_subnet_ids) == 2
    error_message = "Exactly 2 private data subnets are required for high availability."
  }
}

variable "rds_security_group_id" {
  description = "Security group ID for RDS instance"
  type        = string
}
variable "rds_proxy_source_sg_id" {
  description = "Security group ID allowed to connect to RDS Proxy"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

# RDS Proxy Variables
variable "enable_rds_proxy" {
  description = "Enable RDS Proxy for connection pooling"
  type        = bool
  default     = true
}

variable "proxy_max_connections" {
  description = "Max connections for RDS Proxy"
  type        = number
  default     = 100
}

variable "proxy_max_idle_connections" {
  description = "Max idle connections before closing"
  type        = number
  default     = 50
}

variable "proxy_connection_borrow_timeout" {
  description = "Connection borrow timeout in seconds"
  type        = number
  default     = 120
}
