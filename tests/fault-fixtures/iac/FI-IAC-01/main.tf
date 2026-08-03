terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
}

# Positive-control fixture only. This bucket must never be planned or applied.
resource "aws_s3_bucket" "public_positive_control" {
  bucket = "eepistore-never-apply-public-fixture"
}

resource "aws_s3_bucket_public_access_block" "public_positive_control" {
  bucket = aws_s3_bucket.public_positive_control.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
