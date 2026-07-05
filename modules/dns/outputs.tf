output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = local.zone_id
}

output "hosted_zone_name" {
  description = "Route53 hosted zone name"
  value       = var.domain_name
}

output "hosted_zone_name_servers" {
  description = "Name servers for the hosted zone (update domain registrar)"
  value       = var.create_hosted_zone ? aws_route53_zone.main[0].name_servers : []
}

output "health_check_id" {
  description = "Route53 health check ID for ALB"
  value       = local.health_checks_enabled ? aws_route53_health_check.alb[0].id : ""
}

output "health_check_arn" {
  description = "Route53 health check ARN"
  value       = local.health_checks_enabled ? aws_route53_health_check.alb[0].arn : ""
}

output "primary_record_fqdn" {
  description = "Primary domain A record FQDN"
  value       = local.records_enabled ? aws_route53_record.alb_alias[0].fqdn : ""
}

output "www_record_fqdn" {
  description = "WWW subdomain A record FQDN"
  value       = local.records_enabled && var.enable_www_subdomain ? aws_route53_record.www[0].fqdn : ""
}

output "api_record_fqdn" {
  description = "API subdomain A record FQDN"
  value       = local.records_enabled && var.create_api_subdomain ? aws_route53_record.api[0].fqdn : ""
}

output "admin_record_fqdn" {
  description = "Admin subdomain A record FQDN"
  value       = local.records_enabled && var.create_admin_subdomain ? aws_route53_record.admin[0].fqdn : ""
}

output "health_check_alarm_name" {
  description = "CloudWatch alarm name for health check failures"
  value       = local.health_checks_enabled ? aws_cloudwatch_metric_alarm.route53_health_check[0].alarm_name : ""
}

output "query_log_group_name" {
  description = "CloudWatch log group name for Route53 query logs"
  value       = local.records_enabled && var.enable_query_logging ? aws_cloudwatch_log_group.route53_query_logs[0].name : ""
}

output "query_log_group_arn" {
  description = "CloudWatch log group ARN for Route53 query logs"
  value       = local.records_enabled && var.enable_query_logging ? aws_cloudwatch_log_group.route53_query_logs[0].arn : ""
}

output "dns_records_summary" {
  description = "Summary of created DNS records"
  value = {
    primary_domain  = local.records_enabled ? "${var.domain_name} -> ${var.alb_dns_name}" : "Not created"
    www_subdomain   = local.records_enabled && var.enable_www_subdomain ? "www.${var.domain_name} -> ${var.alb_dns_name}" : "Not created"
    api_subdomain   = local.records_enabled && var.create_api_subdomain ? "api.${var.domain_name} -> ${var.alb_dns_name}" : "Not created"
    admin_subdomain = local.records_enabled && var.create_admin_subdomain ? "admin.${var.domain_name} -> ${var.alb_dns_name}" : "Not created"
  }
}
