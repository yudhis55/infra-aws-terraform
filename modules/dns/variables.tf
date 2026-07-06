variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "dev"
}

variable "domain_name" {
  description = "Primary domain name (e.g., example.com)"
  type        = string
  default     = ""
}

variable "create_hosted_zone" {
  description = "Create Route53 hosted zone (set to false if zone already exists)"
  type        = bool
  default     = false
}

variable "hosted_zone_id" {
  description = "Existing Route53 hosted zone ID when create_hosted_zone is false"
  type        = string
  default     = ""
}

variable "alb_dns_name" {
  description = "ALB DNS name to alias to"
  type        = string
}

variable "alb_zone_id" {
  description = "ALB zone ID (AWS account region zone ID)"
  type        = string
}

variable "enable_health_checks" {
  description = "Enable Route53 health checks for ALB endpoint"
  type        = bool
  default     = true
}

variable "enable_www_subdomain" {
  description = "Create www.domain.com subdomain. Keep disabled unless the certificate covers www and no conflicting CNAME already exists."
  type        = bool
  default     = false
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
  description = "Enable TXT records for domain verification (SPF, DKIM, etc)"
  type        = bool
  default     = false
}

variable "txt_verification_records" {
  description = "TXT records for verification (e.g., SPF, DKIM, DMARC records)"
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
  description = "Enable Route53 public hosted zone query logging. This requires a CloudWatch Logs destination in us-east-1 and is disabled by default until that regional wiring is implemented."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention period for Route53 query logs"
  type        = number
  default     = 7

  validation {
    condition     = var.log_retention_days >= 1 && var.log_retention_days <= 3653
    error_message = "Log retention must be between 1 and 3653 days."
  }
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for health check failure notifications (leave empty to disable)"
  type        = string
  default     = ""
}
