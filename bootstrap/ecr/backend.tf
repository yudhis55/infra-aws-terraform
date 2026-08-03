terraform {
  backend "s3" {
    bucket       = "eepistore-dev-terraform-state"
    key          = "eepistore/bootstrap/ecr/terraform.tfstate"
    region       = "ap-southeast-3"
    use_lockfile = true
    kms_key_id   = "arn:aws:kms:ap-southeast-3:557947229844:key/fd2250a6-ed79-4f87-8c18-1d6e14df8e84"
    encrypt      = true
  }
}
