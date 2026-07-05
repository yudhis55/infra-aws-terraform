# NAT Gateway & Elastic IP for Private Subnet Internet Access
# One NAT Gateway per Availability Zone for High Availability

resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-eip-${count.index + 1}"
  }

  depends_on = [var.internet_gateway_id]
}

resource "aws_nat_gateway" "nat" {
  count             = 2
  allocation_id     = aws_eip.nat[count.index].id
  subnet_id         = var.public_subnet_ids[count.index]
  connectivity_type = "public"

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
  }

  depends_on = [var.internet_gateway_id]
}
