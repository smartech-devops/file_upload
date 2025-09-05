# Random password for RDS
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Secrets Manager secret for database credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "csv-processor-db-credentials"
  description = "Database credentials for CSV processor"

  tags = {
    Name = "csv-processor-db-secret"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  identifier = "csv-processor-db"

  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = var.db_storage_type

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  vpc_security_group_ids = [var.rds_security_group_id]
  db_subnet_group_name   = var.db_subnet_group_name

  skip_final_snapshot = var.skip_final_snapshot
  deletion_protection = var.deletion_protection

  # Enable Data API for serverless-like access
  enable_http_endpoint = true

  tags = {
    Name = "csv-processor-database"
  }
}

# Store database credentials in Secrets Manager
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = aws_db_instance.postgres.address
    port     = aws_db_instance.postgres.port
    dbname   = aws_db_instance.postgres.db_name
  })
}

# Initialize database schema using RDS Data API
resource "aws_rdsdata_statement" "create_file_metadata_table" {
  depends_on = [aws_db_instance.postgres, aws_secretsmanager_secret_version.db_credentials]

  resource_arn = aws_db_instance.postgres.arn
  secret_arn   = aws_secretsmanager_secret.db_credentials.arn
  database     = aws_db_instance.postgres.db_name
  
  sql = <<-EOT
    CREATE TABLE IF NOT EXISTS file_metadata (
        id SERIAL PRIMARY KEY,
        filename VARCHAR(255) NOT NULL,
        status VARCHAR(50) NOT NULL,
        timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
  EOT
}

# Create indexes using separate statements
resource "aws_rdsdata_statement" "create_indexes" {
  depends_on = [aws_rdsdata_statement.create_file_metadata_table]

  resource_arn = aws_db_instance.postgres.arn
  secret_arn   = aws_secretsmanager_secret.db_credentials.arn
  database     = aws_db_instance.postgres.db_name
  
  sql = <<-EOT
    CREATE INDEX IF NOT EXISTS idx_file_metadata_filename ON file_metadata(filename);
    CREATE INDEX IF NOT EXISTS idx_file_metadata_timestamp ON file_metadata(timestamp);
    CREATE INDEX IF NOT EXISTS idx_file_metadata_status ON file_metadata(status);
  EOT
}

