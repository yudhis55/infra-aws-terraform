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
  default     = ["*"]
}

variable "public_read_enabled" {
  description = "Deprecated. Public bucket reads are disabled for production; use CloudFront OAC instead."
  type        = bool
  default     = false
}

variable "public_read_prefixes" {
  description = "Object key prefixes that can be publicly read when public_read_enabled is true"
  type        = list(string)
  default     = ["products/*", "avatars/*"]
}

variable "force_destroy" {
  description = "Allow Terraform to delete the bucket even when it contains objects. Keep false for production."
  type        = bool
  default     = false
}
