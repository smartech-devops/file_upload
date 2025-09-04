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

