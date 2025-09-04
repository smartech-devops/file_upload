output "input_bucket_name" {
  description = "Name of the S3 input bucket"
  value       = module.storage.input_bucket_name
}

output "output_bucket_name" {
  description = "Name of the S3 output bucket"
  value       = module.storage.output_bucket_name
}

output "backup_bucket_name" {
  description = "Name of the S3 backup bucket"
  value       = module.storage.backup_bucket_name
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.compute.lambda_function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.compute.lambda_function_arn
}

output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = module.database.db_instance_endpoint
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic"
  value       = module.monitoring.sns_topic_arn
}

output "lambda_vpc_id" {
  description = "ID of the Lambda VPC"
  value       = module.networking.lambda_vpc_id
}

output "rds_vpc_id" {
  description = "ID of the RDS VPC"
  value       = module.networking.rds_vpc_id
}