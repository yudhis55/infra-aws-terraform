output "bucket_id" {
  description = "S3 bucket name for application uploads"
  value       = aws_s3_bucket.app.id
}

output "bucket_arn" {
  description = "S3 bucket ARN for application uploads"
  value       = aws_s3_bucket.app.arn
}

output "bucket_regional_domain_name" {
  description = "Regional S3 domain name"
  value       = aws_s3_bucket.app.bucket_regional_domain_name
}
