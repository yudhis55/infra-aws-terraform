# RDS Proxy for Connection Pooling and IAM Authentication
resource "aws_db_proxy" "main" {
  count                  = var.enable_rds_proxy ? 1 : 0
  name                   = "${var.project_name}-${var.environment}-proxy"
  engine_family          = "POSTGRESQL"
  role_arn               = aws_iam_role.proxy.arn
  vpc_subnet_ids         = var.private_data_subnet_ids
  vpc_security_group_ids = [aws_security_group.proxy.id]
  require_tls            = true
  idle_client_timeout    = 1800

  auth {
    auth_scheme = "SECRETS"
    secret_arn  = var.secrets_manager_secret_arn != "" ? var.secrets_manager_secret_arn : aws_secretsmanager_secret.db_credentials[0].arn
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-proxy"
  }

  depends_on = [aws_iam_role_policy.proxy_policy]
}

resource "aws_db_proxy_default_target_group" "main" {
  count         = var.enable_rds_proxy ? 1 : 0
  db_proxy_name = aws_db_proxy.main[0].name

  connection_pool_config {
    connection_borrow_timeout    = var.proxy_connection_borrow_timeout
    max_connections_percent      = var.proxy_max_connections
    max_idle_connections_percent = var.proxy_max_idle_connections
  }
}

resource "aws_db_proxy_target" "main" {
  count                  = var.enable_rds_proxy ? 1 : 0
  db_instance_identifier = aws_db_instance.main.identifier
  db_proxy_name          = aws_db_proxy.main[0].name
  target_group_name      = aws_db_proxy_default_target_group.main[0].name

  depends_on = [aws_db_instance.main]
}

# Security Group for RDS Proxy
resource "aws_security_group" "proxy" {
  name_prefix = "${var.project_name}-rds-proxy-"
  description = "Security group for RDS Proxy"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.rds_proxy_source_sg_id]
    description     = "Allow PostgreSQL from ECS tasks"
  }

  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.rds_security_group_id]
    description     = "Allow PostgreSQL to RDS"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-proxy-sg"
  }

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = var.rds_proxy_source_sg_id != ""
      error_message = "rds_proxy_source_sg_id is required when RDS Proxy is enabled."
    }
  }
}

resource "aws_security_group_rule" "rds_from_proxy" {
  count                    = var.enable_rds_proxy ? 1 : 0
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = var.rds_security_group_id
  source_security_group_id = aws_security_group.proxy.id
  description              = "Allow PostgreSQL from RDS Proxy"
}

# IAM Role for RDS Proxy
resource "aws_iam_role" "proxy" {
  name_prefix = "${var.project_name}-rds-proxy-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "rds.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-proxy-role"
  }
}

# IAM Policy for RDS Proxy to access Secrets Manager
resource "aws_iam_role_policy" "proxy_policy" {
  name_prefix = "${var.project_name}-rds-proxy-policy-"
  role        = aws_iam_role.proxy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:GetRandomPassword"
        ]
        Resource = [
          var.secrets_manager_secret_arn != "" ? var.secrets_manager_secret_arn : aws_secretsmanager_secret.db_credentials[0].arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = aws_kms_key.rds.arn
      }
    ]
  })
}

# Secrets Manager Secret for DB Credentials (if not provided)
resource "aws_secretsmanager_secret" "db_credentials" {
  count                   = var.secrets_manager_secret_arn == "" ? 1 : 0
  name                    = "${var.project_name}/${var.environment}/rds/credentials"
  description             = "RDS database credentials for ${var.project_name}"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.rds.arn

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  count     = var.secrets_manager_secret_arn == "" ? 1 : 0
  secret_id = aws_secretsmanager_secret.db_credentials[0].id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
  })
}
