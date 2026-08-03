output "instance_id" {
  description = "SSM target instance ID, or null when the experiment agent is disabled"
  value       = try(aws_instance.agent[0].id, null)
}

output "private_ip" {
  description = "Private source IP used to correlate VPC Flow Logs"
  value       = try(aws_instance.agent[0].private_ip, null)
}

output "security_group_id" {
  description = "Dedicated no-ingress experiment agent security group"
  value       = try(aws_security_group.agent[0].id, null)
}

output "role_arn" {
  description = "EC2 role ARN attached to the experiment agent"
  value       = try(aws_iam_role.agent[0].arn, null)
}

output "drift_role_arn" {
  description = "Temporary single-resource, single-tag drift-test role"
  value       = try(aws_iam_role.drift[0].arn, null)
}

output "drift_target_arn" {
  description = "Resource ARN authorized for the controlled tag mutation"
  value       = var.enabled ? var.drift_target_arn : null
}
