variable "bucket_prefix" {
  description = "Prefix for S3 bucket names"
  type        = string
  default     = "candidate-test"
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda function to trigger"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function to trigger"
  type        = string
}