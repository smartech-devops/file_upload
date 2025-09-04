# Lambda VPC
resource "aws_vpc" "lambda_vpc" {
  cidr_block           = var.lambda_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "csv-processor-lambda-vpc"
  }
}

# RDS VPC
resource "aws_vpc" "rds_vpc" {
  cidr_block           = var.rds_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "csv-processor-rds-vpc"
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Lambda VPC subnets
resource "aws_subnet" "lambda_private_a" {
  vpc_id            = aws_vpc.lambda_vpc.id
  cidr_block        = var.lambda_subnet_a_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "csv-processor-lambda-private-a"
  }
}

resource "aws_subnet" "lambda_private_b" {
  vpc_id            = aws_vpc.lambda_vpc.id
  cidr_block        = var.lambda_subnet_b_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "csv-processor-lambda-private-b"
  }
}

# RDS VPC subnets
resource "aws_subnet" "rds_private_a" {
  vpc_id            = aws_vpc.rds_vpc.id
  cidr_block        = var.rds_subnet_a_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "csv-processor-rds-private-a"
  }
}

resource "aws_subnet" "rds_private_b" {
  vpc_id            = aws_vpc.rds_vpc.id
  cidr_block        = var.rds_subnet_b_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "csv-processor-rds-private-b"
  }
}

# VPC Peering Connection
resource "aws_vpc_peering_connection" "lambda_to_rds" {
  vpc_id      = aws_vpc.lambda_vpc.id
  peer_vpc_id = aws_vpc.rds_vpc.id
  auto_accept = true

  tags = {
    Name = "csv-processor-lambda-to-rds-peering"
  }
}

# Route table for Lambda VPC to reach RDS VPC
resource "aws_route_table" "lambda_to_rds" {
  vpc_id = aws_vpc.lambda_vpc.id

  route {
    cidr_block                = aws_vpc.rds_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.lambda_to_rds.id
  }

  tags = {
    Name = "csv-processor-lambda-to-rds-route-table"
  }
}

# Route table for RDS VPC to reach Lambda VPC
resource "aws_route_table" "rds_to_lambda" {
  vpc_id = aws_vpc.rds_vpc.id

  route {
    cidr_block                = aws_vpc.lambda_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.lambda_to_rds.id
  }

  tags = {
    Name = "csv-processor-rds-to-lambda-route-table"
  }
}

# Associate route tables with Lambda subnets
resource "aws_route_table_association" "lambda_private_a" {
  subnet_id      = aws_subnet.lambda_private_a.id
  route_table_id = aws_route_table.lambda_to_rds.id
}

resource "aws_route_table_association" "lambda_private_b" {
  subnet_id      = aws_subnet.lambda_private_b.id
  route_table_id = aws_route_table.lambda_to_rds.id
}

# Associate route tables with RDS subnets
resource "aws_route_table_association" "rds_private_a" {
  subnet_id      = aws_subnet.rds_private_a.id
  route_table_id = aws_route_table.rds_to_lambda.id
}

resource "aws_route_table_association" "rds_private_b" {
  subnet_id      = aws_subnet.rds_private_b.id
  route_table_id = aws_route_table.rds_to_lambda.id
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "csv-processor-subnet-group"
  subnet_ids = [aws_subnet.rds_private_a.id, aws_subnet.rds_private_b.id]

  tags = {
    Name = "csv-processor DB subnet group"
  }
}

# Security Groups
resource "aws_security_group" "lambda" {
  name        = "csv-processor-lambda"
  description = "Security group for Lambda function"
  vpc_id      = aws_vpc.lambda_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "csv-processor-lambda-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "csv-processor-rds"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.rds_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.lambda_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "csv-processor-rds-sg"
  }
}