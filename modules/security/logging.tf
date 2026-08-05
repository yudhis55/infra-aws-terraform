# ==================== VPC Flow Logs for Security Monitoring ====================
# Logs VPC traffic to CloudWatch for security analysis

resource "aws_flow_log" "vpc" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = var.vpc_id

  tags = {
    Name = "${var.project_name}-vpc-flow-logs"
  }

  depends_on = [aws_cloudwatch_log_resource_policy.flow_logs]
}

# ==================== CloudWatch Log Group untuk VPC Flow Logs ====================
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flowlogs/${var.project_name}"
  retention_in_days = 365

  tags = {
    Name = "${var.project_name}-flow-logs"
  }
}

# ==================== IAM Role untuk VPC Flow Logs ====================
resource "aws_iam_role" "flow_logs" {
  name_prefix = "${var.project_name}-flow-logs-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-flow-logs-role"
  }
}

# ==================== IAM Policy untuk VPC Flow Logs ====================
resource "aws_iam_role_policy" "flow_logs" {
  name_prefix = "${var.project_name}-flow-logs-"
  role        = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Effect   = "Allow"
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}

# ==================== CloudWatch Log Resource Policy untuk VPC Flow Logs ====================
resource "aws_cloudwatch_log_resource_policy" "flow_logs" {
  policy_name = "${var.project_name}-flow-logs-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogDelivery",
        "logs:PutResourcePolicy",
        "logs:DescribeResourcePolicies",
        "logs:DescribeLogDeliveries"
      ]
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Resource = "*"
    }]
  })
}

