output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : null
}

output "waf_web_acl_id" {
  description = "ID of the WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].id : null
}

output "waf_web_acl_name" {
  description = "Name of the WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].name : null
}

output "waf_log_group_name" {
  description = "CloudWatch log group name for WAF logs"
  value       = var.enable_waf ? aws_cloudwatch_log_group.waf[0].name : null
}

output "waf_log_group_arn" {
  description = "CloudWatch log group ARN for WAF logs"
  value       = var.enable_waf ? aws_cloudwatch_log_group.waf[0].arn : null
}

output "waf_association_id" {
  description = "ID of the WAF Web ACL association with ALB"
  value       = var.enable_waf ? aws_wafv2_web_acl_association.alb[0].id : null
}

output "vpc_flow_logs_id" {
  description = "ID of VPC Flow Logs"
  value       = aws_flow_log.vpc.id
}

output "vpc_flow_logs_log_group" {
  description = "CloudWatch log group for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.flow_logs.name
}

