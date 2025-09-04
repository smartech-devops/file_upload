terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Networking Module
module "networking" {
  source = "./modules/networking"
}

# Database Module
module "database" {
  source = "./modules/database"
  rds_security_group_id  = module.networking.rds_security_group_id
  db_subnet_group_name   = module.networking.db_subnet_group_name

  depends_on = [module.networking]
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  notification_email  = var.notification_email
  lambda_function_name = "csv-processor"
}

# Storage Module (create buckets first)
module "storage" {
  source = "./modules/storage"
}

# Compute Module (can be created in parallel with database)
module "compute" {
  source = "./modules/compute"
  function_name            = "csv-processor"
  lambda_subnet_ids        = module.networking.lambda_public_subnet_ids
  lambda_security_group_id = module.networking.lambda_security_group_id
  
  # S3 bucket information from storage module
  input_bucket_arn  = module.storage.input_bucket_arn
  output_bucket_arn = module.storage.output_bucket_arn
  backup_bucket_arn = module.storage.backup_bucket_arn
  output_bucket_name = module.storage.output_bucket_name
  backup_bucket_name = module.storage.backup_bucket_name
  
  # Database information from database module (only needs secret ARN, not the actual DB)
  db_secret_arn  = module.database.db_secret_arn
  db_secret_name = module.database.db_secret_name
  
  # SNS information from monitoring module
  sns_topic_arn = module.monitoring.sns_topic_arn

  # Only depends on networking, storage, and monitoring - not the actual database instance
  depends_on = [module.networking, module.storage, module.monitoring]
}

# S3 Event Notification (after both storage and compute are created)
resource "aws_s3_bucket_notification" "input_notification" {
  bucket = module.storage.input_bucket_id

  lambda_function {
    lambda_function_arn = module.compute.lambda_function_arn
    events             = ["s3:ObjectCreated:*"]
    filter_suffix      = ".csv"
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}

# Lambda permission for S3 to invoke the function
resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = module.compute.lambda_function_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.storage.input_bucket_arn
}
