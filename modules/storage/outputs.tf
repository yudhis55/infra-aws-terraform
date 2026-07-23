output "public_bucket_id" {
  description = "S3 bucket name for public media served through CloudFront"
  value       = aws_s3_bucket.app["public"].id
}

output "public_bucket_arn" {
  description = "S3 bucket ARN for public media"
  value       = aws_s3_bucket.app["public"].arn
}

output "public_bucket_regional_domain_name" {
  description = "Regional S3 domain name for the public-media origin"
  value       = aws_s3_bucket.app["public"].bucket_regional_domain_name
}

output "private_bucket_id" {
  description = "S3 bucket name for payment and verification documents"
  value       = aws_s3_bucket.app["private"].id
}

output "private_bucket_arn" {
  description = "S3 bucket ARN for private documents"
  value       = aws_s3_bucket.app["private"].arn
}
