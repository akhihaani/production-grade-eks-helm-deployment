# VPC

resource "aws_vpc" "memos_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = var.tags
}

# Subnets

locals {
  public_subnets = {
    "${var.region}a" = "10.0.0.0/24"
    "${var.region}b" = "10.0.1.0/24"
    "${var.region}c" = "10.0.2.0/24"
  }
  private_subnets = {
    "${var.region}a" = "10.0.10.0/24"
    "${var.region}b" = "10.0.11.0/24"
    "${var.region}c" = "10.0.12.0/24"
  }
}

resource "aws_subnet" "memos_public_subnet" {
  for_each                = local.public_subnets
  vpc_id                  = aws_vpc.memos_vpc.id
  cidr_block              = each.value
  map_public_ip_on_launch = true
  availability_zone       = each.key

  tags = merge(var.tags, {
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "memos_private_subnet" {
  for_each                = local.private_subnets
  vpc_id                  = aws_vpc.memos_vpc.id
  cidr_block              = each.value
  map_public_ip_on_launch = false
  availability_zone       = each.key

  tags = merge(var.tags, {
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# IGW
resource "aws_internet_gateway" "memos_igw" {
  vpc_id = aws_vpc.memos_vpc.id

  tags = var.tags
}

# NAT Gateway

resource "aws_nat_gateway" "memos_nat_gw" {
  allocation_id = aws_eip.memos_nat_eip.id
  subnet_id     = aws_subnet.memos_public_subnet["${var.region}a"].id
  depends_on    = [aws_internet_gateway.memos_igw]

  tags = var.tags
}

resource "aws_eip" "memos_nat_eip" {
  domain = "vpc"

  tags = var.tags
}

# Route Table
resource "aws_route_table" "memos_igw_route_table" {
  vpc_id = aws_vpc.memos_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.memos_igw.id
  }

  tags = var.tags
}

resource "aws_route_table" "memos_natgw_route_table" {
  vpc_id = aws_vpc.memos_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.memos_nat_gw.id
  }
}

resource "aws_route_table_association" "memos_route_table_assoc_public_subnet" {
  for_each       = aws_subnet.memos_public_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.memos_igw_route_table.id
}

resource "aws_route_table_association" "memos_route_table_assoc_private_subnet" {
  for_each       = aws_subnet.memos_private_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.memos_natgw_route_table.id
}
