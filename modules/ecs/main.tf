resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

locals {
  create_alb_security_group = var.create_alb_security_group
  create_ecs_security_group = var.create_ecs_security_group

  alb_security_group_id = local.create_alb_security_group ? aws_security_group.alb_sg[0].id : var.alb_security_group_id
  ecs_security_group_id = local.create_ecs_security_group ? aws_security_group.ecs_sg[0].id : var.ecs_security_group_id
  application_base_url  = var.app_base_url != "" ? var.app_base_url : "http://${aws_lb.main.dns_name}"

  app_environment = [
    {
      name  = "NODE_ENV"
      value = "production"
    },
    {
      name  = "AUTH_URL"
      value = local.application_base_url
    },
    {
      name  = "RDS_HOST"
      value = var.rds_endpoint
    },
    {
      name  = "RDS_PORT"
      value = var.rds_port
    },
    {
      name  = "RDS_DATABASE"
      value = var.rds_database
    },
    {
      name  = "DATABASE_SCHEMA"
      value = "public"
    },
    {
      name  = "RDS_SSLMODE"
      value = "require"
    },
    {
      name  = "S3_BUCKET"
      value = var.s3_bucket_name
    },
    {
      name  = "S3_REGION"
      value = var.s3_region
    },
    {
      name  = "S3_PUBLIC_BASE_URL"
      value = var.s3_public_base_url
    },
    {
      name  = "S3_FORCE_PATH_STYLE"
      value = "false"
    },
    {
      name  = "SMTP_HOST"
      value = var.smtp_host
    },
    {
      name  = "SMTP_PORT"
      value = tostring(var.smtp_port)
    },
    {
      name  = "SMTP_FROM"
      value = var.smtp_from
    }
  ]

  app_secrets = [
    {
      name      = "RDS_USERNAME"
      valueFrom = "${var.rds_secrets_arn}:username::"
    },
    {
      name      = "RDS_PASSWORD"
      valueFrom = "${var.rds_secrets_arn}:password::"
    },
    {
      name      = "AUTH_SECRET"
      valueFrom = "${aws_secretsmanager_secret.app.arn}:AUTH_SECRET::"
    },
    {
      name      = "SMTP_USER"
      valueFrom = "${aws_secretsmanager_secret.app.arn}:SMTP_USER::"
    },
    {
      name      = "SMTP_PASS"
      valueFrom = "${aws_secretsmanager_secret.app.arn}:SMTP_PASS::"
    }
  ]
}

resource "random_password" "auth_secret" {
  length  = 48
  special = true
}

resource "aws_secretsmanager_secret" "app" {
  name_prefix             = "${var.project_name}/${var.environment}/app/"
  description             = "Runtime secrets for ${var.project_name} application"
  recovery_window_in_days = 7

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-secrets"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    AUTH_SECRET = var.auth_secret != "" ? var.auth_secret : random_password.auth_secret.result
    SMTP_USER   = var.smtp_user
    SMTP_PASS   = var.smtp_pass
  })
}

# ==================== ALB & Security Groups ====================

resource "aws_security_group" "alb_sg" {
  count       = local.create_alb_security_group ? 1 : 0
  name        = "${var.project_name}-alb-sg"
  vpc_id      = var.vpc_id
  description = "Security group for ALB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_security_group" "ecs_sg" {
  count       = local.create_ecs_security_group ? 1 : 0
  name        = "${var.project_name}-ecs-sg"
  vpc_id      = var.vpc_id
  description = "Security group for ECS tasks"

  ingress {
    from_port       = 3000
    to_port         = 65535 # Dynamic port range for ECS task ports
    protocol        = "tcp"
    security_groups = [local.alb_security_group_id]
    description     = "Allow traffic from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-ecs-sg"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = [local.alb_security_group_id]

  enable_deletion_protection = true
  drop_invalid_header_fields = true

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb"
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-alb"
  }

  depends_on = [aws_s3_bucket_policy.alb_logs]
}

# ==================== ECS Task Definition ====================

resource "aws_ecs_task_definition" "app" {
  family             = "${var.project_name}-task"
  network_mode       = "bridge" # Bridge mode for EC2 (dynamic port mapping)
  cpu                = var.ecs_task_cpu
  memory             = var.ecs_task_memory
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.ecr_image
      essential = true

      portMappings = [{
        containerPort = 3000
        hostPort      = 0 # Dynamic port mapping for EC2
        protocol      = "tcp"
      }]

      environment = local.app_environment
      secrets     = local.app_secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-task-definition"
  }
}

# CloudWatch Log Group untuk ECS tasks
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-ecs-logs"
  }
}

# ==================== ECS Service ====================

resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.ecs_desired_capacity

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs.name
    weight            = 1
    base              = 1
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_ec2.arn
    container_name   = "app"
    container_port   = 3000
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  depends_on = [
    aws_ecs_cluster_capacity_providers.main,
    aws_lb_listener.http_ec2,
    aws_lb_listener.https
  ]

  tags = {
    Name = "${var.project_name}-service"
  }
}

# ==================== Application Auto Scaling ====================

resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = var.ecs_max_size
  min_capacity       = var.ecs_min_size
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu_scaling" {
  name               = "${var.project_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_appautoscaling_policy" "memory_scaling" {
  name               = "${var.project_name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80.0
  }
}
