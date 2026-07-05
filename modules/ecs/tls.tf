# ==================== HTTPS Listener on ALB ====================
resource "aws_lb_listener" "https" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_ec2.arn
  }

  tags = {
    Name = "${var.project_name}-https-listener"
  }

  lifecycle {
    precondition {
      condition     = var.acm_certificate_arn != ""
      error_message = "acm_certificate_arn is required when enable_https is true."
    }
  }
}

# ==================== HTTP to HTTPS Redirect ====================
# Redirect all HTTP traffic to HTTPS

resource "aws_lb_listener" "http_redirect" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  depends_on = [aws_lb_listener.https]

  tags = {
    Name = "${var.project_name}-http-redirect"
  }
}

