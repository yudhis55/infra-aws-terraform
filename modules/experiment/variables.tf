variable "project_name" {
  description = "Project name used in experiment resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "enabled" {
  description = "Create the private experiment agent"
  type        = bool
  default     = false
}

variable "campaign_id" {
  description = "Approved campaign identifier attached to every temporary resource"
  type        = string
  default     = ""
}

variable "expires_at" {
  description = "UTC expiry timestamp recorded for cleanup governance"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC containing the experiment agent"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR used to constrain connection-test egress"
  type        = string
}

variable "private_subnet_id" {
  description = "Private application subnet for the agent"
  type        = string
}

variable "instance_type" {
  description = "Small instance type used for bounded test generation"
  type        = string
  default     = "t3.small"
}

variable "drift_target_arn" {
  description = "Single project resource ARN whose ExperimentDrift tag may be mutated"
  type        = string
}

variable "experiment_role_arn" {
  description = "GitHub OIDC experiment role permitted to assume the scoped drift role"
  type        = string
}
