# DB Subnet Group for RDS Multi-AZ deployment
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_data_subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

# RDS PostgreSQL Instance with Multi-AZ
resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-${var.environment}-db"
  engine         = "postgres"
  engine_version = var.db_engine_version

  # Database Configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Instance & Storage Configuration
  instance_class     = var.db_instance_class
  allocated_storage  = var.db_allocated_storage
  storage_type       = var.db_storage_type
  iops               = var.db_allocated_storage >= 400 ? var.db_iops : null
  storage_throughput = var.db_allocated_storage >= 400 ? var.db_storage_throughput : null

  # Multi-AZ Configuration
  multi_az             = var.multi_az
  db_subnet_group_name = aws_db_subnet_group.main.name
  publicly_accessible  = false

  # Security & Networking
  vpc_security_group_ids              = [var.rds_security_group_id]
  parameter_group_name                = aws_db_parameter_group.main.name
  iam_database_authentication_enabled = true

  # Backup & Maintenance
  backup_retention_period    = var.backup_retention_period
  backup_window              = var.backup_window
  maintenance_window         = var.maintenance_window
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true

  # Encryption
  storage_encrypted = var.enable_encryption
  kms_key_id        = var.enable_encryption ? aws_kms_key.rds.arn : null

  # Deletion Protection & Final Snapshot
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-final-snapshot"
  deletion_protection       = var.enable_deletion_protection

  # Enable Enhanced Monitoring
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id       = aws_kms_key.rds.arn

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-instance"
    Tier = "data"
  }

  depends_on = [
    aws_db_parameter_group.main,
    aws_iam_role.rds_monitoring
  ]
}

# PostgreSQL Parameter Group for Custom Configuration
resource "aws_db_parameter_group" "main" {
  family      = "postgres15"
  name_prefix = "${var.project_name}-${var.environment}-"
  description = "Custom parameter group for PostgreSQL"

  # Example: Enable log statements
  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-db-param-group"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# KMS Key for RDS Encryption
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "EnableAccountAdministration"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action   = "kms:*"
      Resource = "*"
    }]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-key"
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-${var.environment}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name_prefix = "${var.project_name}-rds-monitoring-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-monitoring-role"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

