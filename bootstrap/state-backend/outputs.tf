output "backend_bucket" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "backend_dynamodb_table" {
  description = "DynamoDB table for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "backend_kms_key_arn" {
  description = "KMS key ARN for Terraform state encryption"
  value       = aws_kms_key.terraform_state.arn
}

output "backend_config" {
  description = "Backend config values to copy into env backend.tf"
  value = {
    bucket         = aws_s3_bucket.terraform_state.bucket
    key            = "eepistore/${var.environment}/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
    kms_key_id     = aws_kms_key.terraform_state.arn
    encrypt        = true
  }
}

