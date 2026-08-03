terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  force_delete = false
}
