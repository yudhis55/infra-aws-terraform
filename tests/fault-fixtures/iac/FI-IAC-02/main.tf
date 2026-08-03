terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
}

# Positive-control fixture only. This security group must never be planned or applied.
resource "aws_security_group" "open_postgres_positive_control" {
  name   = "eepistore-never-apply-open-postgres"
  vpc_id = "vpc-00000000000000000"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
