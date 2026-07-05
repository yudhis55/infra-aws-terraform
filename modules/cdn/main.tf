locals {
  origin_id              = "${var.project_name}-${var.environment}-uploads-origin"
  use_custom_certificate = var.viewer_certificate_acm_arn != "" && length(var.aliases) > 0
}

resource "aws_cloudfront_origin_access_control" "uploads" {
  name                              = "${var.project_name}-${var.environment}-uploads-oac"
  description                       = "Allow CloudFront to read private upload objects"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "uploads" {
  enabled         = true
  is_ipv6_enabled = true
  price_class     = var.price_class
  comment         = "${var.project_name} ${var.environment} upload media CDN"
  aliases         = var.aliases

  origin {
    domain_name              = var.bucket_regional_domain_name
    origin_id                = local.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.uploads.id
  }

  default_cache_behavior {
    target_origin_id       = local.origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = local.use_custom_certificate ? null : true
    acm_certificate_arn            = local.use_custom_certificate ? var.viewer_certificate_acm_arn : null
    ssl_support_method             = local.use_custom_certificate ? "sni-only" : null
    minimum_protocol_version       = local.use_custom_certificate ? "TLSv1.2_2021" : null
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-uploads-cdn"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_policy" "allow_cloudfront" {
  bucket = var.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${var.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.uploads.arn
          }
        }
      }
    ]
  })
}
