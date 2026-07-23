locals {
  buckets = {
    public = {
      name = "public-media"
    }
    private = {
      name = "private-documents"
    }
  }
}

resource "aws_s3_bucket" "app" {
  for_each = local.buckets

  bucket_prefix = "${var.project_name}-${var.environment}-${each.value.name}-"
  force_destroy = var.force_destroy

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.value.name}"
    Environment = var.environment
    Tier        = "storage"
    DataClass   = each.key
  }
}

resource "aws_s3_bucket_ownership_controls" "app" {
  for_each = aws_s3_bucket.app
  bucket   = each.value.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "app" {
  for_each = aws_s3_bucket.app
  bucket   = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  for_each = aws_s3_bucket.app
  bucket   = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app" {
  for_each = aws_s3_bucket.app
  bucket   = each.value.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "app" {
  for_each = aws_s3_bucket.app
  bucket   = each.value.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "PUT"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "app" {
  for_each = aws_s3_bucket.app
  bucket   = each.value.id

  rule {
    id     = "manage-upload-object-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
