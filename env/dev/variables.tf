variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-3"
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# ==================== RDS CONFIGURATION ====================
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "ecommercedb"
}

variable "db_username" {
  description = "Master database username"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

variable "db_password" {
  description = "Master database password (WARNING: Store in tfvars or use Secrets Manager)"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.db_password) >= 8
    error_message = "Database password must be at least 8 characters long."
  }
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.17"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20
}

variable "db_storage_type" {
  description = "RDS storage type"
  type        = string
  default     = "gp3"
}

variable "db_iops" {
  description = "IOPS for gp3/io1 storage"
  type        = number
  default     = 3000
}

variable "db_storage_throughput" {
  description = "Storage throughput for gp3 in MB/s"
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

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy (not recommended for production)"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable RDS deletion protection. Keep true for production-like experiments."
  type        = bool
  default     = true
}

variable "proxy_max_connections" {
  description = "Max connections for RDS Proxy"
  type        = number
  default     = 100
}

variable "proxy_max_idle_connections" {
  description = "Max idle connections for RDS Proxy"
  type        = number
  default     = 50
}

# ==================== ECS CONFIGURATION ====================
variable "ecs_instance_type" {
  description = "EC2 instance type for ECS (t3.small=2GB, t3.medium=4GB, t3.large=8GB)"
  type        = string
  default     = "t3.medium"

  validation {
    condition     = can(regex("^t3\\.(small|medium|large|xlarge)$", var.ecs_instance_type))
    error_message = "Instance type must be t3.small, t3.medium, t3.large, or t3.xlarge."
  }
}

variable "ecs_min_size" {
  description = "Minimum number of ECS EC2 instances"
  type        = number
  default     = 2

  validation {
    condition     = var.ecs_min_size >= 1 && var.ecs_min_size <= 10
    error_message = "Min size must be between 1 and 10."
  }
}

variable "ecs_max_size" {
  description = "Maximum number of ECS EC2 instances"
  type        = number
  default     = 6

  validation {
    condition     = var.ecs_max_size >= 2 && var.ecs_max_size <= 20
    error_message = "Max size must be between 2 and 20."
  }
}

variable "ecs_desired_capacity" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "ecs_task_cpu" {
  description = "CPU units for ECS task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Memory for ECS task in MB (depends on instance type)"
  type        = number
  default     = 512
}

variable "app_image_uri" {
  description = "Immutable application image URI for ECS, usually ECR repository URL tagged with the Git commit SHA"
  type        = string

  validation {
    condition     = can(regex(":[0-9a-f]{40}$", var.app_image_uri)) || can(regex("@sha256:[0-9a-f]{64}$", var.app_image_uri))
    error_message = "app_image_uri must use an immutable commit SHA tag or image digest, not latest."
  }
}

variable "secrets_manager_secret_arn" {
  description = "ARN of custom Secrets Manager secret for RDS (leave empty to use RDS-created secret)"
  type        = string
  default     = ""
}

# ==================== APPLICATION RUNTIME CONFIGURATION ====================
variable "app_base_url" {
  description = "Public application base URL used by auth callbacks. Leave empty to use the ALB DNS name."
  type        = string
  default     = ""
}

variable "auth_secret" {
  description = "Optional NextAuth/Auth.js secret. Leave empty to generate one in Secrets Manager."
  type        = string
  default     = ""
  sensitive   = true
}

variable "health_check_path" {
  description = "ALB target group health check path"
  type        = string
  default     = "/api/health"
}

variable "s3_cors_allowed_origins" {
  description = "Origins allowed to upload files to S3 through presigned URLs"
  type        = list(string)
  default     = ["*"]
}

variable "smtp_host" {
  description = "SMTP host used by the application"
  type        = string
  default     = ""
}

variable "smtp_port" {
  description = "SMTP port used by the application"
  type        = number
  default     = 587
}

variable "smtp_user" {
  description = "SMTP username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "smtp_pass" {
  description = "SMTP password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "smtp_from" {
  description = "Default sender address for application emails"
  type        = string
  default     = "noreply@eepistore.local"
}

variable "cloudfront_price_class" {
  description = "CloudFront price class for public media CDN"
  type        = string
  default     = "PriceClass_100"
}

# ==================== HTTPS & TLS CONFIGURATION ====================
variable "enable_https" {
  description = "Enable HTTPS listener on ALB. Requires acm_certificate_arn."
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the ALB HTTPS listener"
  type        = string
  default     = ""
}

# ==================== SECURITY & WAF CONFIGURATION ====================
variable "enable_waf" {
  description = "Enable AWS WAF protection for ALB"
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "WAF rate limit threshold (requests per 5 minutes)"
  type        = number
  default     = 2000

  validation {
    condition     = var.waf_rate_limit >= 100 && var.waf_rate_limit <= 20000000
    error_message = "WAF rate limit must be between 100 and 20,000,000."
  }
}

# ==================== MONITORING & CLOUDWATCH CONFIGURATION ====================
variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications (leave empty to disable)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring (more metrics, higher cost)"
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

# ==================== DNS & ROUTE53 CONFIGURATION ====================
variable "domain_name" {
  description = "Primary domain name for Route53 (e.g., example.com) - set to empty string to skip DNS setup"
  type        = string
  default     = ""
}

variable "create_hosted_zone" {
  description = "Create Route53 hosted zone (set to false if zone already exists)"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Existing Route53 hosted zone ID. Required when create_hosted_zone is false and domain_name is set."
  type        = string
  default     = ""
}

variable "enable_health_checks" {
  description = "Enable Route53 health checks for ALB endpoint"
  type        = bool
  default     = true
}

variable "enable_www_subdomain" {
  description = "Create www.domain.com subdomain"
  type        = bool
  default     = true
}

variable "create_api_subdomain" {
  description = "Create api.domain.com subdomain"
  type        = bool
  default     = false
}

variable "create_admin_subdomain" {
  description = "Create admin.domain.com subdomain"
  type        = bool
  default     = false
}

variable "enable_mx_record" {
  description = "Enable MX records for mail delivery"
  type        = bool
  default     = false
}

variable "mx_records" {
  description = "MX records for email (e.g., ['10 mail.example.com'])"
  type        = list(string)
  default     = []
}

variable "enable_txt_verification_record" {
  description = "Enable TXT records for domain verification (SPF, DKIM, DMARC)"
  type        = bool
  default     = false
}

variable "txt_verification_records" {
  description = "TXT records for verification (SPF, DKIM, DMARC records)"
  type        = list(string)
  default     = []
}

variable "enable_cdn_cname" {
  description = "Create CNAME record for CloudFront CDN"
  type        = bool
  default     = false
}

variable "cdn_subdomain" {
  description = "CDN subdomain name (e.g., 'cdn' for cdn.example.com)"
  type        = string
  default     = "cdn"
}

variable "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  type        = string
  default     = ""
}

variable "enable_query_logging" {
  description = "Enable Route53 query logging to CloudWatch"
  type        = bool
  default     = true
}
