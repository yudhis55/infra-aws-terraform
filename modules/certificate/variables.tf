variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "certificate_purpose" {
  description = "Short purpose label used in tags, for example alb or media"
  type        = string
  default     = "alb"
}

variable "domain_name" {
  description = "Primary domain name for the certificate"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID used for DNS validation"
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional DNS names for the certificate"
  type        = list(string)
  default     = []
}
