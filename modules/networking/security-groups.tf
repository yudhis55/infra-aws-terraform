# Security Groups for Networking Tier
# Separates ingress/egress rules for ALB, ECS, RDS, and internal communication

# ==================== ALB SECURITY GROUP ====================
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ==================== ECS SECURITY GROUP ====================
resource "aws_security_group" "ecs" {
  name_prefix = "${var.project_name}-ecs-"
  description = "Security group for ECS Container Instances and Tasks"
  vpc_id      = var.vpc_id

  # ECS EC2 bridge mode registers dynamic host ports in the target group.
  ingress {
    from_port       = 32768
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow ALB to reach ECS dynamic host ports"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ==================== RDS SECURITY GROUP ====================
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  description = "Security group for RDS Database Instance"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allow_ecs_direct_rds_access ? [1] : []

    content {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [aws_security_group.ecs.id]
      description     = "Break-glass direct PostgreSQL access from ECS"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
