# VPC Endpoints for Private Subnet to AWS Services Integration
# Allows private subnets to access AWS services without internet gateway

# ==================== SECURITY GROUP FOR INTERFACE ENDPOINTS ====================
resource "aws_security_group" "vpc_endpoint_sg" {
  name_prefix = "${var.project_name}-vpc-endpoint-"
  description = "Security group for VPC Endpoints - allow HTTPS from private subnets"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
    description     = "Allow HTTPS from ECS tasks"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc-endpoint-sg"
  }
}

# ==================== S3 GATEWAY ENDPOINT ====================
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    aws_route_table.private_app[*].id,
    [aws_route_table.private_data.id]
  )

  tags = {
    Name = "${var.project_name}-${var.environment}-s3-endpoint"
  }
}

# S3 Endpoint Policy - Allow private subnets access to S3
resource "aws_vpc_endpoint_policy" "s3" {
  vpc_endpoint_id = aws_vpc_endpoint.s3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = contains(var.s3_endpoint_allowed_bucket_arns, "*") ? ["*"] : concat(
          var.s3_endpoint_allowed_bucket_arns,
          [for arn in var.s3_endpoint_allowed_bucket_arns : "${arn}/*"]
        )
      }
    ]
  })
}

# ==================== ECR API INTERFACE ENDPOINT ====================
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_app_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-${var.environment}-ecr-api-endpoint"
  }
}

# ==================== ECR DKR INTERFACE ENDPOINT ====================
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_app_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-${var.environment}-ecr-dkr-endpoint"
  }
}

# ==================== SECRETS MANAGER INTERFACE ENDPOINT ====================
resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_app_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-${var.environment}-secrets-manager-endpoint"
  }
}

# ==================== CLOUDWATCH LOGS INTERFACE ENDPOINT ====================
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_app_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-${var.environment}-cloudwatch-logs-endpoint"
  }
}
