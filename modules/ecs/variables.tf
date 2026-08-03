variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnets" {
  description = "Public subnets for ALB"
  type        = list(string)
}

variable "private_app_subnets" {
  description = "Private application subnets for EC2 instances"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ALB security group ID owned by the networking module"
  type        = string
}

variable "ecs_security_group_id" {
  description = "ECS security group ID owned by the networking module"
  type        = string
}

variable "ecr_image" {
  description = "ECR image URI for ECS task"
  type        = string
}

# ==================== EC2 Auto Scaling Configuration ====================
variable "ecs_instance_type" {
  description = "EC2 instance type for ECS"
  type        = string
  default     = "t3.medium" # t3.small = 2GB memory, t3.medium = 4GB memory
}

variable "asg_min_size" {
  description = "Minimum number of EC2 instances in ASG"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of EC2 instances in ASG"
  type        = number
  default     = 6
}

variable "asg_desired_capacity" {
  description = "Desired number of EC2 instances in ASG"
  type        = number
  default     = 2
}

variable "service_min_tasks" {
  description = "Minimum number of ECS application tasks"
  type        = number
  default     = 2
}

variable "service_max_tasks" {
  description = "Maximum number of ECS application tasks"
  type        = number
  default     = 6
}

variable "service_desired_count" {
  description = "Desired number of ECS application tasks"
  type        = number
  default     = 2
}

variable "service_request_count_target" {
  description = "Average ALB requests per target per minute used by ECS target tracking"
  type        = number
  default     = 300

  validation {
    condition     = var.service_request_count_target >= 100 && var.service_request_count_target <= 1000
    error_message = "service_request_count_target must remain between 100 and 1000 requests per target per minute."
  }
}

# ==================== ECS Task Configuration ====================
variable "ecs_task_cpu" {
  description = "CPU units for ECS task (256 = 0.25vCPU)"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Memory for ECS task in MB"
  type        = number
  default     = 512
}

# ==================== RDS Configuration ====================
variable "rds_endpoint" {
  description = "RDS instance endpoint (hostname without port)"
  type        = string
}

variable "rds_port" {
  description = "RDS instance port"
  type        = string
  default     = "5432"
}

variable "rds_database" {
  description = "RDS database name"
  type        = string
  default     = "ecommercedb"
}

variable "rds_secrets_arn" {
  description = "ARN of Secrets Manager secret containing RDS credentials"
  type        = string
}

# ==================== Application Runtime Configuration ====================
variable "app_base_url" {
  description = "Public application base URL used by auth callbacks. Leave empty to use the ALB DNS name."
  type        = string
  default     = ""
}

variable "app_secrets_kms_key_id" {
  description = "KMS key ARN or ID used to encrypt application runtime secrets."
  type        = string
  default     = ""
}

variable "s3_public_bucket_name" {
  description = "S3 bucket name for public media"
  type        = string
}

variable "s3_public_bucket_arn" {
  description = "S3 bucket ARN for public media"
  type        = string
}

variable "s3_private_bucket_name" {
  description = "S3 bucket name for private documents"
  type        = string
}

variable "s3_private_bucket_arn" {
  description = "S3 bucket ARN for private documents"
  type        = string
}

variable "s3_region" {
  description = "Region for application S3 bucket"
  type        = string
}

variable "s3_public_base_url" {
  description = "Public base URL for non-sensitive media objects, usually CloudFront"
  type        = string
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

variable "smtp_from" {
  description = "Default sender address for application emails"
  type        = string
  default     = "noreply@eepistore.local"
}

variable "health_check_path" {
  description = "ALB target group health check path"
  type        = string
  default     = "/api/health"
}

variable "alb_logs_force_destroy" {
  description = "Allow Terraform to delete ALB access log bucket contents during controlled teardown."
  type        = bool
  default     = false
}

variable "enable_https" {
  description = "Enable HTTPS listener on ALB"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable ALB deletion protection. Keep true for production-like experiments."
  type        = bool
  default     = true
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the ALB HTTPS listener"
  type        = string
  default     = ""
}
