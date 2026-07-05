# Route Tables for Private Subnets
# Separate route tables for App Tier and Data Tier

# ==================== APP TIER ROUTES ====================
# Private App Tier Route Table - Each AZ has its own for optimal NAT routing
resource "aws_route_table" "private_app" {
  count  = 2
  vpc_id = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-private-app-rt-${count.index + 1}"
    Tier = "app"
  }
}

# Route from App Tier to Internet via NAT Gateway (same AZ)
resource "aws_route" "private_app_to_nat" {
  count                  = 2
  route_table_id         = aws_route_table.private_app[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[count.index].id
}

# Associate App Tier Route Table to Private App Subnets
resource "aws_route_table_association" "private_app" {
  count          = 2
  subnet_id      = var.private_app_subnet_ids[count.index]
  route_table_id = aws_route_table.private_app[count.index].id
}

# ==================== DATA TIER ROUTES ====================
# Private Data Tier Route Table - No internet access, VPC internal only
resource "aws_route_table" "private_data" {
  vpc_id = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-private-data-rt"
    Tier = "data"
  }
}

# Associate Data Tier Route Table to Private Data Subnets
resource "aws_route_table_association" "private_data" {
  count          = 2
  subnet_id      = var.private_data_subnet_ids[count.index]
  route_table_id = aws_route_table.private_data.id
}

# Optional: VPC Peering Routes can be added here if needed in future
