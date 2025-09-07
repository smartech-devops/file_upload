# DB Parameter Group with logging enabled
resource "aws_db_parameter_group" "postgres_logging" {
  family = "postgres15"
  name   = "${var.db_identifier}-logging"
  description = "PostgreSQL parameter group with comprehensive logging"

  parameter {
    name  = "log_statement"
    value = "all"  # Log all statements (DDL, DML, etc.)
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "0"  # Log all queries (set to higher value like 1000 to only log slow queries)
  }

  parameter {
    name  = "log_connections"
    value = "1"  # Log connection attempts
  }

  parameter {
    name  = "log_disconnections"
    value = "1"  # Log disconnections
  }

  parameter {
    name  = "log_checkpoints"
    value = "1"  # Log checkpoints
  }

  parameter {
    name  = "log_lock_waits"
    value = "1"  # Log lock waits
  }

  tags = {
    Name = "${var.db_identifier}-parameter-group"
  }
}

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
  identifier = var.db_identifier

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

  # Use custom parameter group for logging
  parameter_group_name = aws_db_parameter_group.postgres_logging.name

  auto_minor_version_upgrade = false
  skip_final_snapshot = var.skip_final_snapshot
  deletion_protection = var.deletion_protection

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

