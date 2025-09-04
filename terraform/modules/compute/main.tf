# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "csv-processor-lambda-logs"
  }
}

# Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "csv-processor-lambda-role"

  assume_role_policy = file("${path.root}/policies/lambda-assume-role-policy.json")

  tags = {
    Name = "csv-processor-lambda-role"
  }
}

# Lambda IAM Policy
resource "aws_iam_role_policy" "lambda_policy" {
  name = "csv-processor-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = templatefile("${path.root}/policies/lambda-execution-policy.json", {
    input_bucket_arn  = var.input_bucket_arn
    output_bucket_arn = var.output_bucket_arn
    backup_bucket_arn = var.backup_bucket_arn
    db_secret_arn     = var.db_secret_arn
    sns_topic_arn     = var.sns_topic_arn
  })
}

# Lambda Function
resource "aws_lambda_function" "csv_processor" {
  function_name = var.function_name
  role         = aws_iam_role.lambda_role.arn

  filename         = var.deployment_package_path
  source_code_hash = filebase64sha256(var.deployment_package_path)

  handler = var.handler
  runtime = var.runtime
  timeout = var.timeout

  vpc_config {
    subnet_ids         = var.lambda_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      OUTPUT_BUCKET   = var.output_bucket_name
      BACKUP_BUCKET   = var.backup_bucket_name
      DB_SECRET_NAME  = var.db_secret_name
      SNS_TOPIC_ARN   = var.sns_topic_arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]

  tags = {
    Name = "csv-processor-lambda-function"
  }
}