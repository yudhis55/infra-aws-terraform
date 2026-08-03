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

variable "experiment_mode" {
  description = "Temporary WAF mode: off, rate-test, or performance"
  type        = string
  default     = "off"

  validation {
    condition     = contains(["off", "rate-test", "performance"], var.experiment_mode)
    error_message = "experiment_mode must be off, rate-test, or performance."
  }
}

variable "experiment_source_ipv4" {
  description = "Fixed public IPv4 source without CIDR suffix; required for a temporary WAF mode"
  type        = string
  default     = ""

  validation {
    condition     = var.experiment_source_ipv4 == "" || can(cidrhost("${var.experiment_source_ipv4}/32", 0))
    error_message = "experiment_source_ipv4 must be a valid IPv4 address without a CIDR suffix."
  }
}

variable "experiment_rate_limit" {
  description = "Bounded WAF test threshold in the 60-second evaluation window"
  type        = number
  default     = 100

  validation {
    condition     = var.experiment_rate_limit >= 10 && var.experiment_rate_limit <= 100
    error_message = "experiment_rate_limit must be between 10 and the preregistered maximum of 100."
  }
}
