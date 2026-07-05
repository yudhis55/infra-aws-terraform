# ==================== EC2 Instance IAM Role ====================
# Role untuk EC2 instances yang menjalankan ECS tasks

resource "aws_iam_role" "ecs_instance_role" {
  name_prefix = "${var.project_name}-ecs-instance-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-ecs-instance-role"
  }
}

# Attach policy untuk ECS container agent
resource "aws_iam_role_policy_attachment" "ecs_instance_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Attach policy untuk SSM Session Manager (debugging)
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile untuk attach role ke EC2
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name_prefix = "${var.project_name}-ecs-ip-"
  role        = aws_iam_role.ecs_instance_role.name
}

# ==================== ECS Task Execution Role ====================
# Role yang digunakan oleh ECS task untuk execute container

resource "aws_iam_role" "ecs_task_execution_role" {
  name_prefix = "${var.project_name}-ecs-task-exec-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-ecs-task-exec-role"
  }
}

# Attach standard ECS task execution policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow ECS agent to inject Secrets Manager values into container env vars.
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name_prefix = "${var.project_name}-ecs-task-secrets-read-"
  role        = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          var.rds_secrets_arn,
          aws_secretsmanager_secret.app.arn
        ]
      }
      ],
      var.app_secrets_kms_key_id != "" ? [{
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = var.app_secrets_kms_key_id
      }] : []
    )
  })
}

# ==================== ECS Task Role ====================
# Role yang digunakan oleh container applications (with access to RDS, Secrets Manager)

resource "aws_iam_role" "ecs_task_role" {
  name_prefix = "${var.project_name}-ecs-task-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-ecs-task-role"
  }
}

# Policy untuk app containers - akses Secrets Manager
resource "aws_iam_role_policy" "ecs_task_secrets_policy" {
  name_prefix = "${var.project_name}-ecs-task-secrets-"
  role        = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          var.rds_secrets_arn,
          aws_secretsmanager_secret.app.arn
        ]
      }
      ],
      var.app_secrets_kms_key_id != "" ? [{
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = var.app_secrets_kms_key_id
      }] : []
    )
  })
}

resource "aws_iam_role_policy" "ecs_task_s3_policy" {
  name_prefix = "${var.project_name}-ecs-task-s3-"
  role        = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.s3_bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${var.s3_bucket_arn}/*"
      }
    ]
  })
}

# Get current AWS account ID dan region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
