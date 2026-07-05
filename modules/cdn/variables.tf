variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "bucket_id" {
  description = "S3 bucket name used as the CloudFront origin"
  type        = string
}

variable "bucket_arn" {
  description = "S3 bucket ARN used as the CloudFront origin"
  type        = string
}

variable "bucket_regional_domain_name" {
  description = "Regional S3 bucket domain name"
  type        = string
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

