terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
}

# Positive-control fixture only. This security group must never be planned or applied.
resource "aws_security_group" "unrestricted_ingress_positive_control" {
  name   = "eepistore-never-apply-unrestricted-ingress"
  vpc_id = "vpc-00000000000000000"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
