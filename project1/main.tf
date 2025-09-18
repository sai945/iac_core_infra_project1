# VPC - preprod or non-prod vpc 
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.vpc_env}-vpc"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = {
    Name        = "${var.environment}-public-subnet-${count.index + 1}"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Private Subnets - Web Layer
resource "aws_subnet" "private_weblayer" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 2)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.environment}-private-weblayer-subnet-${count.index + 1}"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Private Subnets - App Layer
resource "aws_subnet" "private_applayer" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 4)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.environment}-private-applayer-subnet-${count.index + 1}"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Private Subnets - Database
resource "aws_subnet" "private_dblayer" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 6)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.environment}-private-dblayer-subnet-${count.index + 1}"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-igw"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.environment}-nat-eip"
    Environment = var.environment
    Terraform   = "true"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "${var.environment}-nat-gateway"
    Environment = var.environment
    Terraform   = "true"
  }

  depends_on = [aws_internet_gateway.main]
}

# Network ACLs
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name        = "${var.environment}-public-nacl"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_network_acl" "private" {
  vpc_id = aws_vpc.main.id
  subnet_ids = concat(
    aws_subnet.private_weblayer[*].id,
    aws_subnet.private_applayer[*].id,
    aws_subnet.private_dblayer[*].id
  )

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name        = "${var.environment}-private-nacl"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.environment}-public-rt"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "${var.environment}-private-rt"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Web layer private subnets
resource "aws_route_table_association" "private_weblayer" {
  count          = length(aws_subnet.private_weblayer[*].id)
  subnet_id      = aws_subnet.private_weblayer[count.index].id
  route_table_id = aws_route_table.private.id
}

# App layer private subnets
resource "aws_route_table_association" "private_applayer" {
  count          = length(aws_subnet.private_applayer[*].id)
  subnet_id      = aws_subnet.private_applayer[count.index].id
  route_table_id = aws_route_table.private.id
}

# DB layer private subnets
resource "aws_route_table_association" "private_dblayer" {
  count          = length(aws_subnet.private_dblayer[*].id)
  subnet_id      = aws_subnet.private_dblayer[count.index].id
  route_table_id = aws_route_table.private.id
}



# Security Groups
resource "aws_security_group" "bastion" {
  name        = "${var.environment}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidr_blocks
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-bastion-sg"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_security_group" "windows_admin" {
  name        = "${var.environment}-windows-admin-sg"
  description = "Security group for Windows admin access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3389
    to_port         = 3389
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-windows-admin-sg"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_security_group" "linux_admin" {
  name        = "${var.environment}-linux-admin-sg"
  description = "Security group for Linux admin access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-linux-admin-sg"
    Environment = var.environment
    Terraform   = "true"
  }
}
