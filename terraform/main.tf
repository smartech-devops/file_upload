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

# Compute Module
module "compute" {
  source = "./modules/compute"
  function_name            = "csv-processor"
  lambda_subnet_ids        = module.networking.lambda_subnet_ids
  lambda_security_group_id = module.networking.lambda_security_group_id
  
  # S3 bucket information from storage module
  input_bucket_arn  = module.storage.input_bucket_arn
  output_bucket_arn = module.storage.output_bucket_arn
  backup_bucket_arn = module.storage.backup_bucket_arn
  output_bucket_name = module.storage.output_bucket_name
  backup_bucket_name = module.storage.backup_bucket_name
  
  # Database information from database module
  db_secret_arn  = module.database.db_secret_arn
  db_secret_name = module.database.db_secret_name
  
  # SNS information from monitoring module
  sns_topic_arn = module.monitoring.sns_topic_arn

  depends_on = [module.networking, module.database, module.storage, module.monitoring]
}

# Storage Module (depends on compute for Lambda ARN)
module "storage" {
  source = "./modules/storage"
  lambda_function_arn  = module.compute.lambda_function_arn
  lambda_function_name = module.compute.lambda_function_name

  depends_on = [module.compute]
}