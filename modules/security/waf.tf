# ==================== AWS WAF Web ACL ====================
# Web ACL untuk melindungi ALB dari common web attacks

resource "aws_wafv2_web_acl" "main" {
  count = var.enable_waf ? 1 : 0
  name  = "${var.project_name}-waf-acl"
  scope = "REGIONAL"

  # AWS must observe the Web ACL rule update before Terraform removes the
  # temporary IP set during experiment cleanup.
  depends_on = [aws_wafv2_ip_set.experiment_source]

  default_action {
    allow {}
  }

  # ==================== SQL Injection Protection ====================
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesSQLiRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # ==================== XSS Protection ====================
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # ==================== Common Rule Set ====================
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # No overrides
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = var.experiment_mode == "performance" ? [1] : []
    content {
      name     = "ExperimentPerformanceAllow"
      priority = 4

      action {
        allow {}
      }

      statement {
        and_statement {
          statement {
            ip_set_reference_statement {
              arn = aws_wafv2_ip_set.experiment_source[0].arn
            }
          }
          statement {
            or_statement {
              statement {
                byte_match_statement {
                  positional_constraint = "EXACTLY"
                  search_string         = "/products"
                  field_to_match {
                    uri_path {}
                  }
                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }
              statement {
                byte_match_statement {
                  positional_constraint = "EXACTLY"
                  search_string         = "/api/health"
                  field_to_match {
                    uri_path {}
                  }
                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "ExperimentPerformanceAllowMetric"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.experiment_mode == "rate-test" ? [1] : []
    content {
      name     = "ExperimentRateLimit"
      priority = 5

      action {
        block {
          custom_response {
            response_code = 429
          }
        }
      }

      statement {
        rate_based_statement {
          limit                 = var.experiment_rate_limit
          aggregate_key_type    = "IP"
          evaluation_window_sec = 60
          scope_down_statement {
            and_statement {
              statement {
                ip_set_reference_statement {
                  arn = aws_wafv2_ip_set.experiment_source[0].arn
                }
              }
              statement {
                byte_match_statement {
                  positional_constraint = "EXACTLY"
                  search_string         = "/api/experiment/rate-limit"
                  field_to_match {
                    uri_path {}
                  }
                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "ExperimentRateLimitMetric"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.experiment_mode == "rate-test" ? [1] : []
    content {
      name     = "ExperimentRateUnderLimitAllow"
      priority = 6
      action {
        allow {}
      }

      statement {
        and_statement {
          statement {
            ip_set_reference_statement {
              arn = aws_wafv2_ip_set.experiment_source[0].arn
            }
          }
          statement {
            byte_match_statement {
              positional_constraint = "EXACTLY"
              search_string         = "/api/experiment/rate-limit"
              field_to_match {
                uri_path {}
              }
              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "ExperimentRateUnderLimitAllowMetric"
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "ExperimentEndpointPermanentDeny"
    priority = 7

    action {
      block {
        custom_response {
          response_code = 403
        }
      }
    }

    statement {
      byte_match_statement {
        positional_constraint = "EXACTLY"
        search_string         = "/api/experiment/rate-limit"
        field_to_match {
          uri_path {}
        }
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "ExperimentEndpointPermanentDenyMetric"
      sampled_requests_enabled   = true
    }
  }

  # ==================== Rate Limiting ====================
  rule {
    name     = "RateLimitingRule"
    priority = 8

    action {
      block {
        custom_response {
          response_code = 429
        }
      }
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitingRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  # ==================== IP Reputation List ====================
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 9

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationListMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf-metrics"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.project_name}-waf"
    Environment = var.environment
  }
}

# ==================== WAF Association dengan ALB ====================
resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.enable_waf ? 1 : 0
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn
}

resource "aws_wafv2_ip_set" "experiment_source" {
  count              = var.enable_waf && var.experiment_mode != "off" ? 1 : 0
  name               = "${var.project_name}-experiment-source"
  description        = "Temporary source allowlist for bounded thesis experiments"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = ["${var.experiment_source_ipv4}/32"]

  tags = {
    Environment = var.environment
    Temporary   = "true"
  }
}

# ==================== CloudWatch Log Group untuk WAF ====================
resource "aws_cloudwatch_log_group" "waf" {
  count             = var.enable_waf ? 1 : 0
  name              = "aws-waf-logs-${var.project_name}"
  retention_in_days = 365

  tags = {
    Name = "${var.project_name}-waf-logs"
  }
}

# ==================== WAF Logging Configuration ====================
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count                   = var.enable_waf ? 1 : 0
  resource_arn            = aws_wafv2_web_acl.main[0].arn
  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]

  logging_filter {
    default_behavior = "KEEP"

    filter {
      behavior = "KEEP"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }

      requirement = "MEETS_ANY"
    }
  }

  depends_on = [
    aws_cloudwatch_log_resource_policy.waf
  ]
}

# ==================== IAM Policy untuk WAF CloudWatch Logs ====================
resource "aws_cloudwatch_log_resource_policy" "waf" {
  count       = var.enable_waf ? 1 : 0
  policy_name = "${var.project_name}-waf-logs-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.waf[0].arn}:*"
      }
    ]
  })
}
