terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
}

# Positive-control fixture only. This database must never be planned or applied.
resource "aws_db_instance" "public_unencrypted_positive_control" {
  identifier                  = "eepistore-never-apply-public-rds"
  engine                      = "postgres"
  instance_class              = "db.t3.micro"
  allocated_storage           = 20
  username                    = "fixture"
  manage_master_user_password = true
  publicly_accessible         = true
  storage_encrypted           = false
  skip_final_snapshot         = true
}
