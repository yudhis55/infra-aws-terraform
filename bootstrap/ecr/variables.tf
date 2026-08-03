variable "aws_region" {
  description = "AWS region for the immutable application repository"
  type        = string
  default     = "ap-southeast-3"
}

variable "project_name" {
  description = "Project name used by the ECR module"
  type        = string
  default     = "eepistore"
}
