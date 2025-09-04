# Random suffix for unique bucket names
resource "random_id" "suffix" {
  byte_length = 4
}

# S3 Buckets
resource "aws_s3_bucket" "input" {
  bucket = "${var.bucket_prefix}-input-${random_id.suffix.hex}"

  tags = {
    Name    = "csv-processor-input-bucket"
    Purpose = "CSV file uploads"
  }
}

resource "aws_s3_bucket" "output" {
  bucket = "${var.bucket_prefix}-output-${random_id.suffix.hex}"

  tags = {
    Name    = "csv-processor-output-bucket"
    Purpose = "Processing results"
  }
}

resource "aws_s3_bucket" "backup" {
  bucket = "${var.bucket_prefix}-backup-${random_id.suffix.hex}"

  tags = {
    Name    = "csv-processor-backup-bucket"
    Purpose = "File archival"
  }
}

# S3 Event Notification to trigger Lambda
resource "aws_s3_bucket_notification" "input_notification" {
  bucket = aws_s3_bucket.input.id

  lambda_function {
    lambda_function_arn = var.lambda_function_arn
    events             = ["s3:ObjectCreated:*"]
    filter_suffix      = ".csv"
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}

# Lambda permission for S3 to invoke the function
resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.input.arn
}