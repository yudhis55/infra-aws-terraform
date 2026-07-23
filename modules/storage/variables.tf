variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "cors_allowed_origins" {
  description = "Origins allowed to upload objects through browser presigned URLs"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for origin in var.cors_allowed_origins : origin != "*" && can(regex("^https?://", origin))])
    error_message = "S3 CORS origins must be explicit HTTP(S) origins; wildcard '*' is not allowed."
  }
}

variable "force_destroy" {
  description = "Allow Terraform to delete storage buckets even when they contain objects. Keep false for production."
  type        = bool
  default     = false
}
