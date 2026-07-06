variable "project_name" {}

variable "force_delete" {
  description = "Allow Terraform to delete the ECR repository even when it contains images. Keep false except controlled teardown."
  type        = bool
  default     = false
}
