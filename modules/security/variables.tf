variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "dev"
}

variable "alb_arn" {
  description = "ARN of the Application Load Balancer to protect with WAF"
  type        = string
}

variable "enable_waf" {
  description = "Enable AWS WAF for ALB protection"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "VPC ID for VPC Flow Logs"
  type        = string
}

variable "waf_rate_limit" {
  description = "Rate limit threshold for WAF (requests per 5 minutes)"
  type        = number
  default     = 2000

  validation {
    condition     = var.waf_rate_limit >= 100 && var.waf_rate_limit <= 20000000
    error_message = "WAF rate limit must be between 100 and 20,000,000."
  }
}

variable "enable_block_mode" {
  description = "Enable block mode for WAF (true) or count mode (false) for testing"
  type        = bool
  default     = true
}
