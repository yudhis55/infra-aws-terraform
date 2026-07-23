variable "project_name" {
  description = "Project name used for the ECR repository and resource tags."
  type        = string
}

variable "force_delete" {
  description = "Allow Terraform to delete the ECR repository even when it contains images. Keep false except controlled teardown."
  type        = bool
  default     = false
}
