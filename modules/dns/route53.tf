# ==================== Route53 Hosted Zone ====================
# Primary hosted zone untuk domain management

resource "aws_route53_zone" "main" {
  count = var.create_hosted_zone ? 1 : 0
  name  = var.domain_name

  tags = {
    Name        = "${var.project_name}-hosted-zone"
    Environment = var.environment
  }
}

locals {
  zone_id               = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : var.hosted_zone_id
  records_enabled       = var.domain_name != "" && local.zone_id != ""
  health_checks_enabled = local.records_enabled && var.enable_health_checks
  cdn_record_enabled    = local.records_enabled && var.enable_cdn_cname
}

# ==================== Route53 Health Check untuk ALB ====================
# Health check untuk memverifikasi ALB endpoint availability

resource "aws_route53_health_check" "alb" {
  count             = local.health_checks_enabled ? 1 : 0
  fqdn              = var.domain_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/api/health"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "${var.project_name}-alb-health-check"
  }

  depends_on = []
}

# ==================== Route53 Record - ALB Alias (Primary) ====================
# Alias record pointing to ALB dengan health check

resource "aws_route53_record" "alb_alias" {
  count   = local.records_enabled ? 1 : 0
  zone_id = local.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = local.health_checks_enabled
  }
}

# ==================== Route53 Record - www subdomain ====================
# www subdomain redirects to primary domain

resource "aws_route53_record" "www" {
  count   = local.records_enabled && var.enable_www_subdomain ? 1 : 0
  zone_id = local.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = local.health_checks_enabled
  }

}

# ==================== Route53 Record - API subdomain (Optional) ====================
# API subdomain for backend service

resource "aws_route53_record" "api" {
  count   = local.records_enabled && var.create_api_subdomain ? 1 : 0
  zone_id = local.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = local.health_checks_enabled
  }

}

# ==================== Route53 Record - Admin subdomain (Optional) ====================
# Admin subdomain untuk admin panel

resource "aws_route53_record" "admin" {
  count   = local.records_enabled && var.create_admin_subdomain ? 1 : 0
  zone_id = local.zone_id
  name    = "admin.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = local.health_checks_enabled
  }

}

# ==================== Route53 Record - MX Record (Mail) ====================
# MX record untuk email delivery (optional, untuk custom mail server)

resource "aws_route53_record" "mx" {
  count   = local.records_enabled && var.enable_mx_record ? 1 : 0
  zone_id = local.zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = 300

  records = var.mx_records

}

# ==================== Route53 Record - TXT Record (Verification) ====================
# TXT record untuk domain verification (SPF, DKIM, DMARC, site verification)

resource "aws_route53_record" "txt_verification" {
  count   = local.records_enabled && var.enable_txt_verification_record ? 1 : 0
  zone_id = local.zone_id
  name    = var.domain_name
  type    = "TXT"
  ttl     = 300

  records = var.txt_verification_records

}

# ==================== Route53 Record - CNAME untuk CDN (Optional) ====================
# CNAME record untuk CloudFront distribution jika ada

resource "aws_route53_record" "cdn" {
  count   = local.cdn_record_enabled ? 1 : 0
  zone_id = local.zone_id
  name    = var.cdn_subdomain
  type    = "CNAME"
  ttl     = 300

  records = [var.cloudfront_domain_name]

}

# ==================== CloudWatch Alarm untuk Route53 Health Check ====================
resource "aws_cloudwatch_metric_alarm" "route53_health_check" {
  count               = local.health_checks_enabled ? 1 : 0
  alarm_name          = "${var.project_name}-route53-health-check-status"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Alert when Route53 health check fails"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    HealthCheckId = aws_route53_health_check.alb[0].id
  }

  tags = {
    Name = "${var.project_name}-route53-health"
  }

  depends_on = [aws_route53_health_check.alb]
}

# ==================== Route53 Query Logging ====================
# Log DNS queries ke CloudWatch untuk audit dan troubleshooting

resource "aws_cloudwatch_log_group" "route53_query_logs" {
  count             = local.records_enabled && var.enable_query_logging ? 1 : 0
  name              = "/aws/route53/${var.domain_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-route53-logs"
  }
}

resource "aws_route53_query_log" "main" {
  count                    = local.records_enabled && var.enable_query_logging ? 1 : 0
  zone_id                  = local.zone_id
  cloudwatch_log_group_arn = "${aws_cloudwatch_log_group.route53_query_logs[0].arn}:*"

  depends_on = [aws_cloudwatch_log_group.route53_query_logs]
}

# ==================== IAM Role untuk Route53 Query Logging ====================
resource "aws_iam_role" "route53_query_logging" {
  count       = local.records_enabled && var.enable_query_logging ? 1 : 0
  name_prefix = "${var.project_name}-route53-query-logging-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "route53.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-route53-logging-role"
  }
}

resource "aws_iam_role_policy" "route53_query_logging" {
  count       = local.records_enabled && var.enable_query_logging ? 1 : 0
  name_prefix = "${var.project_name}-route53-query-logging-"
  role        = aws_iam_role.route53_query_logging[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.route53_query_logs[0].arn}:*"
    }]
  })
}
