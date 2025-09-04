#!/bin/bash

# Test: S3 Lambda Trigger
# Tests S3 bucket notification triggering Lambda function

set -e

echo "Testing S3 Lambda trigger integration..."

# Generate test file
TEST_FILE="test-trigger-$(date +%s).csv"
TEST_CONTENT="id,name,email
1,John Doe,john@example.com
2,Jane Smith,jane@example.com"

echo "Creating test CSV file: $TEST_FILE"
echo "$TEST_CONTENT" > "/tmp/$TEST_FILE"

# Get initial Lambda invocation count
echo "Getting initial Lambda metrics..."
INITIAL_INVOCATIONS=$(aws cloudwatch get-metric-statistics \
    --namespace "AWS/Lambda" \
    --metric-name "Invocations" \
    --dimensions Name=FunctionName,Value="$LAMBDA_FUNCTION_NAME" \
    --statistics "Sum" \
    --start-time "$(date -d '5 minutes ago' -u +%Y-%m-%dT%H:%M:%S)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
    --period 300 \
    --region "$AWS_REGION" \
    --query 'Datapoints[0].Sum' \
    --output text 2>/dev/null || echo "0")

if [ "$INITIAL_INVOCATIONS" = "None" ]; then
    INITIAL_INVOCATIONS=0
fi

echo "Initial invocation count: $INITIAL_INVOCATIONS"

# Upload test file to S3 input bucket
echo "Uploading test file to S3..."
aws s3 cp "/tmp/$TEST_FILE" "s3://$INPUT_BUCKET_NAME/$TEST_FILE" --region "$AWS_REGION"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to upload test file to S3"
    exit 1
fi

echo "✓ Test file uploaded successfully"

# Wait for Lambda to be triggered (S3 events are usually processed within seconds)
echo "Waiting for Lambda to be triggered..."
sleep 30

# Check CloudWatch logs for Lambda execution
echo "Checking Lambda execution logs..."
LOG_GROUP_NAME="/aws/lambda/$LAMBDA_FUNCTION_NAME"

# Get recent log streams
LOG_STREAMS=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP_NAME" \
    --order-by "LastEventTime" \
    --descending \
    --max-items 5 \
    --region "$AWS_REGION" \
    --query 'logStreams[].logStreamName' \
    --output text 2>/dev/null || echo "")

if [ -z "$LOG_STREAMS" ]; then
    echo "WARNING: No log streams found for Lambda function"
else
    echo "✓ Found Lambda log streams"
    
    # Check recent logs for our test file
    RECENT_LOGS=""
    for stream in $LOG_STREAMS; do
        LOGS=$(aws logs get-log-events \
            --log-group-name "$LOG_GROUP_NAME" \
            --log-stream-name "$stream" \
            --start-time "$(($(date +%s) * 1000 - 300000))" \
            --region "$AWS_REGION" \
            --query 'events[].message' \
            --output text 2>/dev/null || echo "")
        
        if echo "$LOGS" | grep -q "$TEST_FILE"; then
            echo "✓ Found log entry mentioning test file: $TEST_FILE"
            RECENT_LOGS="$LOGS"
            break
        fi
    done
    
    if [ -z "$RECENT_LOGS" ]; then
        echo "WARNING: Test file not found in recent Lambda logs"
    fi
fi

# Check updated Lambda invocation count
echo "Checking updated Lambda metrics..."
sleep 30  # Wait a bit more for metrics to update

FINAL_INVOCATIONS=$(aws cloudwatch get-metric-statistics \
    --namespace "AWS/Lambda" \
    --metric-name "Invocations" \
    --dimensions Name=FunctionName,Value="$LAMBDA_FUNCTION_NAME" \
    --statistics "Sum" \
    --start-time "$(date -d '10 minutes ago' -u +%Y-%m-%dT%H:%M:%S)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
    --period 600 \
    --region "$AWS_REGION" \
    --query 'Datapoints[0].Sum' \
    --output text 2>/dev/null || echo "0")

if [ "$FINAL_INVOCATIONS" = "None" ]; then
    FINAL_INVOCATIONS=0
fi

echo "Final invocation count: $FINAL_INVOCATIONS"

# Check if invocation count increased
if [ "$FINAL_INVOCATIONS" -gt "$INITIAL_INVOCATIONS" ]; then
    echo "✓ Lambda invocation count increased - trigger working!"
else
    echo "WARNING: Lambda invocation count did not increase"
    echo "This might indicate the trigger is not working or metrics are delayed"
fi

# Check for Lambda errors
echo "Checking for Lambda errors..."
ERROR_COUNT=$(aws cloudwatch get-metric-statistics \
    --namespace "AWS/Lambda" \
    --metric-name "Errors" \
    --dimensions Name=FunctionName,Value="$LAMBDA_FUNCTION_NAME" \
    --statistics "Sum" \
    --start-time "$(date -d '10 minutes ago' -u +%Y-%m-%dT%H:%M:%S)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
    --period 600 \
    --region "$AWS_REGION" \
    --query 'Datapoints[0].Sum' \
    --output text 2>/dev/null || echo "0")

if [ "$ERROR_COUNT" = "None" ]; then
    ERROR_COUNT=0
fi

if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "WARNING: Lambda function had $ERROR_COUNT errors during execution"
else
    echo "✓ No Lambda errors detected"
fi

# Check if file was processed (moved to output or backup bucket)
echo "Checking if file was processed..."
sleep 10

# Check output bucket for processed file
OUTPUT_FILES=$(aws s3 ls "s3://$OUTPUT_BUCKET_NAME/" --region "$AWS_REGION" | grep "$TEST_FILE" || echo "")
if [ -n "$OUTPUT_FILES" ]; then
    echo "✓ Processed file found in output bucket"
fi

# Check backup bucket for original file
BACKUP_FILES=$(aws s3 ls "s3://$BACKUP_BUCKET_NAME/" --region "$AWS_REGION" | grep "$TEST_FILE" || echo "")
if [ -n "$BACKUP_FILES" ]; then
    echo "✓ Original file found in backup bucket"
fi

# Clean up test files
echo "Cleaning up test files..."
rm -f "/tmp/$TEST_FILE"
aws s3 rm "s3://$INPUT_BUCKET_NAME/$TEST_FILE" --region "$AWS_REGION" 2>/dev/null || true
aws s3 rm "s3://$OUTPUT_BUCKET_NAME/$TEST_FILE" --region "$AWS_REGION" 2>/dev/null || true
aws s3 rm "s3://$BACKUP_BUCKET_NAME/$TEST_FILE" --region "$AWS_REGION" 2>/dev/null || true

echo "✅ S3 Lambda trigger test completed!"

# Return success if no critical errors
if [ "$FINAL_INVOCATIONS" -gt "$INITIAL_INVOCATIONS" ] || [ -n "$OUTPUT_FILES" ] || [ -n "$BACKUP_FILES" ]; then
    echo "✅ Test passed - Lambda was triggered by S3 event"
    exit 0
else
    echo "❌ Test inconclusive - Lambda may not have been triggered"
    exit 1
fi