output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.uploads.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.uploads.arn
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.uploads.domain_name
}

output "public_base_url" {
  description = "Base URL for public media objects"
  value       = "https://${var.public_domain_name != "" ? var.public_domain_name : aws_cloudfront_distribution.uploads.domain_name}"
}
