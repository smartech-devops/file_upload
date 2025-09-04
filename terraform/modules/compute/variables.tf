variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "csv-processor"
}

variable "deployment_package_path" {
  description = "Path to the Lambda deployment package"
  type        = string
  default     = "../lambda-deployment.zip"
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.12"
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "lambda_subnet_ids" {
  description = "List of subnet IDs for Lambda VPC configuration"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda function"
  type        = string
}

variable "input_bucket_arn" {
  description = "ARN of the input S3 bucket"
  type        = string
}

variable "output_bucket_arn" {
  description = "ARN of the output S3 bucket"
  type        = string
}

variable "backup_bucket_arn" {
  description = "ARN of the backup S3 bucket"
  type        = string
}

variable "output_bucket_name" {
  description = "Name of the output S3 bucket"
  type        = string
}

variable "backup_bucket_name" {
  description = "Name of the backup S3 bucket"
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the database secret"
  type        = string
}

variable "db_secret_name" {
  description = "Name of the database secret"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic"
  type        = string
}