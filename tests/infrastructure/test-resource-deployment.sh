#!/bin/bash

# Test: Resource Deployment
# Validates that all AWS resources are properly deployed and configured

set -e

echo "Testing resource deployment..."

# Test Lambda function deployment
echo "Checking Lambda function deployment..."
LAMBDA_ARN=$(aws lambda get-function \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --query 'Configuration.FunctionArn' \
    --output text --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -z "$LAMBDA_ARN" ]; then
    echo "ERROR: Lambda function not found: $LAMBDA_FUNCTION_NAME"
    exit 1
fi

echo "✓ Lambda function deployed: $LAMBDA_FUNCTION_NAME"

# Test Lambda configuration
LAMBDA_STATE=$(aws lambda get-function \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --query 'Configuration.State' \
    --output text --region "$AWS_REGION")

if [ "$LAMBDA_STATE" != "Active" ]; then
    echo "ERROR: Lambda function is not active. State: $LAMBDA_STATE"
    exit 1
fi

echo "✓ Lambda function is active"

# Test S3 buckets
echo "Checking S3 buckets..."

# Input bucket
aws s3 ls "s3://$INPUT_BUCKET_NAME" >/dev/null 2>&1 || {
    echo "ERROR: Input bucket not accessible: $INPUT_BUCKET_NAME"
    exit 1
}
echo "✓ Input bucket accessible: $INPUT_BUCKET_NAME"

# Output bucket
aws s3 ls "s3://$OUTPUT_BUCKET_NAME" >/dev/null 2>&1 || {
    echo "ERROR: Output bucket not accessible: $OUTPUT_BUCKET_NAME"
    exit 1
}
echo "✓ Output bucket accessible: $OUTPUT_BUCKET_NAME"

# Backup bucket
aws s3 ls "s3://$BACKUP_BUCKET_NAME" >/dev/null 2>&1 || {
    echo "ERROR: Backup bucket not accessible: $BACKUP_BUCKET_NAME"
    exit 1
}
echo "✓ Backup bucket accessible: $BACKUP_BUCKET_NAME"

# Test S3 bucket notification configuration
echo "Checking S3 event notification..."
NOTIFICATION_CONFIG=$(aws s3api get-bucket-notification-configuration \
    --bucket "$INPUT_BUCKET_NAME" \
    --query 'LambdaConfigurations[0].LambdaFunctionArn' \
    --output text --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -z "$NOTIFICATION_CONFIG" ]; then
    echo "ERROR: S3 bucket notification not configured for input bucket"
    exit 1
fi

echo "✓ S3 bucket notification configured"

# Test RDS instance
echo "Checking RDS instance..."
DB_IDENTIFIER=$(aws rds describe-db-instances \
    --query 'DBInstances[?contains(DBInstanceIdentifier,`csv-processor`)].DBInstanceIdentifier' \
    --output text --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -z "$DB_IDENTIFIER" ]; then
    echo "ERROR: RDS instance not found"
    exit 1
fi

DB_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text --region "$AWS_REGION")

if [ "$DB_STATUS" != "available" ]; then
    echo "ERROR: RDS instance is not available. Status: $DB_STATUS"
    exit 1
fi

echo "✓ RDS instance available: $DB_IDENTIFIER"

# Test Secrets Manager
echo "Checking Secrets Manager..."
SECRET_ARN=$(aws secretsmanager describe-secret \
    --secret-id "$DB_SECRET_NAME" \
    --query 'ARN' \
    --output text --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -z "$SECRET_ARN" ]; then
    echo "ERROR: Database secret not found: $DB_SECRET_NAME"
    exit 1
fi

echo "✓ Database secret found: $DB_SECRET_NAME"

# Test SNS topic
echo "Checking SNS topic..."
TOPIC_ATTRIBUTES=$(aws sns get-topic-attributes \
    --topic-arn "$SNS_TOPIC_ARN" \
    --query 'Attributes.TopicArn' \
    --output text --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -z "$TOPIC_ATTRIBUTES" ]; then
    echo "ERROR: SNS topic not found: $SNS_TOPIC_ARN"
    exit 1
fi

echo "✓ SNS topic found: $SNS_TOPIC_ARN"

# Test VPC resources
echo "Checking VPC resources..."

# Lambda VPC
LAMBDA_VPC=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=csv-processor-lambda-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text --region "$AWS_REGION")

if [ "$LAMBDA_VPC" = "None" ] || [ -z "$LAMBDA_VPC" ]; then
    echo "ERROR: Lambda VPC not found"
    exit 1
fi

echo "✓ Lambda VPC found: $LAMBDA_VPC"

# RDS VPC
RDS_VPC=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=csv-processor-rds-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text --region "$AWS_REGION")

if [ "$RDS_VPC" = "None" ] || [ -z "$RDS_VPC" ]; then
    echo "ERROR: RDS VPC not found"
    exit 1
fi

echo "✓ RDS VPC found: $RDS_VPC"

# Test subnets
echo "Checking subnets..."

# Lambda private subnets
LAMBDA_SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=csv-processor-lambda-private-*" \
    --query 'length(Subnets)' \
    --output text --region "$AWS_REGION")

if [ "$LAMBDA_SUBNETS" -lt 2 ]; then
    echo "ERROR: Expected 2 Lambda private subnets, found: $LAMBDA_SUBNETS"
    exit 1
fi

echo "✓ Lambda private subnets found: $LAMBDA_SUBNETS"

# Lambda public subnets
LAMBDA_PUBLIC_SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=csv-processor-lambda-public-*" \
    --query 'length(Subnets)' \
    --output text --region "$AWS_REGION")

if [ "$LAMBDA_PUBLIC_SUBNETS" -lt 2 ]; then
    echo "ERROR: Expected 2 Lambda public subnets, found: $LAMBDA_PUBLIC_SUBNETS"
    exit 1
fi

echo "✓ Lambda public subnets found: $LAMBDA_PUBLIC_SUBNETS"

# RDS private subnets
RDS_SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=csv-processor-rds-private-*" \
    --query 'length(Subnets)' \
    --output text --region "$AWS_REGION")

if [ "$RDS_SUBNETS" -lt 2 ]; then
    echo "ERROR: Expected 2 RDS private subnets, found: $RDS_SUBNETS"
    exit 1
fi

echo "✓ RDS private subnets found: $RDS_SUBNETS"

echo "✅ Resource deployment test passed!"