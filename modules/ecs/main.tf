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
  alb_security_group_id = var.alb_security_group_id
  ecs_security_group_id = var.ecs_security_group_id
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
      name  = "S3_PUBLIC_BUCKET"
      value = var.s3_public_bucket_name
    },
    {
      name  = "S3_PRIVATE_BUCKET"
      value = var.s3_private_bucket_name
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
  kms_key_id              = var.app_secrets_kms_key_id != "" ? var.app_secrets_kms_key_id : null

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-secrets"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    AUTH_SECRET = random_password.auth_secret.result
  })
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = [local.alb_security_group_id]

  enable_deletion_protection = var.enable_deletion_protection
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
      name                   = "app"
      image                  = var.ecr_image
      essential              = true
      readonlyRootFilesystem = true

      linuxParameters = {
        tmpfs = [{
          containerPath = "/tmp"
          size          = 64
          mountOptions  = ["rw", "noexec", "nosuid", "nodev"]
        }]
      }

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
  retention_in_days = 365

  tags = {
    Name = "${var.project_name}-ecs-logs"
  }
}

# ==================== ECS Service ====================

resource "aws_ecs_service" "app" {
  name                 = "${var.project_name}-service"
  cluster              = aws_ecs_cluster.main.id
  task_definition      = aws_ecs_task_definition.app.arn
  desired_count        = var.service_desired_count
  force_new_deployment = true

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
  health_check_grace_period_seconds  = 120

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_ecs_cluster_capacity_providers.main,
    aws_iam_role_policy_attachment.ecs_task_execution_policy,
    aws_lb_listener.http_ec2,
    aws_lb_listener.https
  ]

  tags = {
    Name = "${var.project_name}-service"
  }
}

# ==================== Application Auto Scaling ====================

resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = var.service_max_tasks
  min_capacity       = var.service_min_tasks
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
