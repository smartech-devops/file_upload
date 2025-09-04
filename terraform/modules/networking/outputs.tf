output "lambda_vpc_id" {
  description = "ID of the Lambda VPC"
  value       = aws_vpc.lambda_vpc.id
}

output "rds_vpc_id" {
  description = "ID of the RDS VPC"
  value       = aws_vpc.rds_vpc.id
}

output "lambda_subnet_ids" {
  description = "List of Lambda subnet IDs"
  value       = [aws_subnet.lambda_private_a.id, aws_subnet.lambda_private_b.id]
}

output "rds_subnet_ids" {
  description = "List of RDS subnet IDs"
  value       = [aws_subnet.rds_private_a.id, aws_subnet.rds_private_b.id]
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.main.name
}

output "lambda_security_group_id" {
  description = "ID of the Lambda security group"
  value       = aws_security_group.lambda.id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

# Public subnet outputs
output "lambda_public_subnet_ids" {
  description = "List of Lambda public subnet IDs"
  value       = [aws_subnet.lambda_public_a.id, aws_subnet.lambda_public_b.id]
}

output "rds_public_subnet_ids" {
  description = "List of RDS public subnet IDs"
  value       = [aws_subnet.rds_public_a.id, aws_subnet.rds_public_b.id]
}

# Internet gateway outputs
output "lambda_igw_id" {
  description = "ID of the Lambda Internet Gateway"
  value       = aws_internet_gateway.lambda_igw.id
}

output "rds_igw_id" {
  description = "ID of the RDS Internet Gateway"
  value       = aws_internet_gateway.rds_igw.id
}