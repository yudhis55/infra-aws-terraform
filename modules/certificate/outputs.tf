output "certificate_arn" {
  description = "Validated ACM certificate ARN"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "certificate_domain_name" {
  description = "Primary certificate domain name"
  value       = aws_acm_certificate.main.domain_name
}

