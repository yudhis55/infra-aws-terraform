variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "internet_gateway_id" {
  description = "Internet Gateway ID for NAT dependency"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs (2 AZs)"
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_ids) == 2
    error_message = "Exactly 2 public subnets are required for high availability."
  }
}

variable "private_app_subnet_ids" {
  description = "List of private application tier subnet IDs (2 AZs)"
  type        = list(string)
  validation {
    condition     = length(var.private_app_subnet_ids) == 2
    error_message = "Exactly 2 private app subnets are required for high availability."
  }
}

variable "private_data_subnet_ids" {
  description = "List of private data tier subnet IDs (2 AZs)"
  type        = list(string)
  validation {
    condition     = length(var.private_data_subnet_ids) == 2
    error_message = "Exactly 2 private data subnets are required for high availability."
  }
}

variable "allow_ecs_direct_rds_access" {
  description = "Allow ECS security group to connect directly to RDS. Keep false when RDS Proxy is the application path."
  type        = bool
  default     = false
}

variable "s3_endpoint_allowed_bucket_arns" {
  description = "S3 bucket ARNs reachable through the gateway endpoint"
  type        = list(string)
  default     = ["*"]
}
