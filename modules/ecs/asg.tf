# ==================== ECS Optimized AMI Data Source ====================
# Get latest ECS-optimized Amazon Linux 2 AMI

data "aws_ami" "ecs_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ==================== EC2 Launch Template ====================
# Template untuk launching ECS-optimized EC2 instances

resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.project_name}-ecs-lt-"
  image_id      = data.aws_ami.ecs_ami.id
  instance_type = var.ecs_instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  vpc_security_group_ids = [local.ecs_security_group_id]

  # User data untuk initialize ECS cluster
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    cluster_name = aws_ecs_cluster.main.name
    region       = data.aws_region.current.name
  }))

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-ecs-instance"
      Environment = var.environment
      Project     = var.project_name
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.project_name}-ecs-volume"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ==================== Auto Scaling Group ====================
# Scale EC2 instances across multiple AZs

resource "aws_autoscaling_group" "ecs" {
  name                      = "${var.project_name}-asg"
  min_size                  = var.ecs_min_size
  max_size                  = var.ecs_max_size
  desired_capacity          = var.ecs_desired_capacity
  health_check_type         = "EC2"
  health_check_grace_period = 300
  vpc_zone_identifier       = var.private_app_subnets

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  depends_on = [aws_ecs_cluster.main]
}

# The ASG is exposed to ECS through a capacity provider so ECS can place tasks
# and scale EC2 capacity as part of one schedulable pool.
resource "aws_ecs_capacity_provider" "ecs" {
  name = "${var.project_name}-${var.environment}-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 80
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 2
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.ecs.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs.name
    weight            = 1
    base              = 1
  }
}

# ==================== Target Group for EC2 ====================
# ECS uses bridge mode with dynamic host ports. The ECS service, not the ASG,
# registers the selected instance:port targets into this target group.

resource "aws_lb_target_group" "ecs_ec2" {
  name_prefix = "ecs-"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance" # Changed from "ip" (Fargate) to "instance" (EC2)

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    matcher             = "200-299"
  }

  tags = {
    Name = "${var.project_name}-ecs-tg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Update ALB listener untuk menggunakan new target group
resource "aws_lb_listener" "http_ec2" {
  count             = var.enable_https ? 0 : 1
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_ec2.arn
  }
}
