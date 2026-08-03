data "aws_ssm_parameter" "al2023" {
  count = var.enabled ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "agent" {
  count       = var.enabled ? 1 : 0
  name_prefix = "${var.project_name}-experiment-agent-"
  description = "No-ingress security group for the bounded experiment agent"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS to owned public endpoints, SSM, and package sources"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Exact PostgreSQL connection-denial tests inside the VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Known ECS dynamic-port connection-denial test inside the VPC"
    from_port   = 32768
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "VPC DNS over UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "VPC DNS over TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name         = "${var.project_name}-${var.environment}-experiment-agent-sg"
    Environment  = var.environment
    ExperimentId = var.campaign_id
    ExpiresAt    = var.expires_at
    Temporary    = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "agent" {
  count = var.enabled ? 1 : 0
  name  = "${var.project_name}-experiment-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment  = var.environment
    ExperimentId = var.campaign_id
    ExpiresAt    = var.expires_at
    Temporary    = "true"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.agent[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "agent" {
  count = var.enabled ? 1 : 0
  name  = "${var.project_name}-experiment-agent-profile"
  role  = aws_iam_role.agent[0].name
}

resource "aws_instance" "agent" {
  count = var.enabled ? 1 : 0

  ami                         = data.aws_ssm_parameter.al2023[0].value
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.agent[0].id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.agent[0].name
  user_data_replace_on_change = true
  monitoring                  = true
  ebs_optimized               = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 12
  }

  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    dnf install -y docker jq
    systemctl enable --now docker
  EOT

  tags = {
    Name         = "${var.project_name}-${var.environment}-experiment-agent"
    Environment  = var.environment
    ExperimentId = var.campaign_id
    ExpiresAt    = var.expires_at
    Temporary    = "true"
  }

  depends_on = [aws_iam_role_policy_attachment.ssm]
}

resource "aws_iam_role" "drift" {
  count = var.enabled ? 1 : 0
  name  = "${var.project_name}-experiment-drift-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = var.experiment_role_arn }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment  = var.environment
    ExperimentId = var.campaign_id
    ExpiresAt    = var.expires_at
    Temporary    = "true"
  }
}

resource "aws_iam_role_policy" "drift" {
  count = var.enabled ? 1 : 0
  name  = "single-tag-single-resource"
  role  = aws_iam_role.drift[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CreateOnlyControlledDriftTag"
        Effect   = "Allow"
        Action   = "ec2:CreateTags"
        Resource = var.drift_target_arn
        Condition = {
          "ForAllValues:StringEquals" = { "aws:TagKeys" = ["ExperimentDrift"] }
          StringEquals                = { "aws:RequestTag/ExperimentDrift" = "controlled" }
        }
      },
      {
        Sid      = "RemoveOnlyControlledDriftTag"
        Effect   = "Allow"
        Action   = "ec2:DeleteTags"
        Resource = var.drift_target_arn
        Condition = {
          "ForAllValues:StringEquals" = { "aws:TagKeys" = ["ExperimentDrift"] }
        }
      }
    ]
  })
}
