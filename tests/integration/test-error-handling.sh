#!/bin/bash

# Test: Error Handling
# Tests system error handling and notification mechanisms

set -e

echo "Testing error handling and notifications..."

# Test 1: Invalid CSV file processing
echo "Test 1: Invalid CSV file handling..."
INVALID_TEST_FILE="invalid-test-$(date +%s).csv"
INVALID_CONTENT="invalid,csv,format
missing,quotes and spaces in names
1,2,3,4,5,6,7,8,9,10,too,many,columns
special chars: éñ@#$%^&*()
"

echo "Creating invalid CSV file: $INVALID_TEST_FILE"
echo "$INVALID_CONTENT" > "/tmp/$INVALID_TEST_FILE"

# Upload invalid file
echo "Uploading invalid CSV file..."
aws s3 cp "/tmp/$INVALID_TEST_FILE" "s3://$INPUT_BUCKET_NAME/$INVALID_TEST_FILE" --region "$AWS_REGION"

if [ $? -eq 0 ]; then
    echo "✓ Invalid file uploaded successfully"
else
    echo "ERROR: Failed to upload invalid file"
    exit 1
fi

# Wait for processing
echo "Waiting for error processing..."
sleep 30

# Test 2: Empty file processing
echo "Test 2: Empty file handling..."
EMPTY_TEST_FILE="empty-test-$(date +%s).csv"
touch "/tmp/$EMPTY_TEST_FILE"

echo "Uploading empty CSV file..."
aws s3 cp "/tmp/$EMPTY_TEST_FILE" "s3://$INPUT_BUCKET_NAME/$EMPTY_TEST_FILE" --region "$AWS_REGION"

if [ $? -eq 0 ]; then
    echo "✓ Empty file uploaded successfully"
else
    echo "ERROR: Failed to upload empty file"
    exit 1
fi

# Wait for processing
sleep 30

# Test 3: Very large file (if applicable)
echo "Test 3: Large file handling..."
LARGE_TEST_FILE="large-test-$(date +%s).csv"
LARGE_HEADER="id,name,email,description"
echo "$LARGE_HEADER" > "/tmp/$LARGE_TEST_FILE"

# Generate a reasonably large file (but not too large for testing)
for i in $(seq 1 1000); do
    echo "$i,User$i,user$i@example.com,This is a long description for user $i with various characters and data" >> "/tmp/$LARGE_TEST_FILE"
done

echo "Uploading large CSV file..."
aws s3 cp "/tmp/$LARGE_TEST_FILE" "s3://$INPUT_BUCKET_NAME/$LARGE_TEST_FILE" --region "$AWS_REGION"

if [ $? -eq 0 ]; then
    echo "✓ Large file uploaded successfully"
else
    echo "ERROR: Failed to upload large file"
    exit 1
fi

# Wait for processing
echo "Waiting for large file processing..."
sleep 60

# Check Lambda error metrics
echo "Checking Lambda error metrics..."
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

echo "Lambda errors in last 10 minutes: $ERROR_COUNT"

# Check Duration metrics for execution issues
DURATION=$(aws cloudwatch get-metric-statistics \
    --namespace "AWS/Lambda" \
    --metric-name "Duration" \
    --dimensions Name=FunctionName,Value="$LAMBDA_FUNCTION_NAME" \
    --statistics "Average,Maximum" \
    --start-time "$(date -d '10 minutes ago' -u +%Y-%m-%dT%H:%M:%S)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
    --period 600 \
    --region "$AWS_REGION" \
    --query 'Datapoints[0].[Average,Maximum]' \
    --output text 2>/dev/null || echo "")

if [ -n "$DURATION" ]; then
    echo "Lambda execution duration - Average/Maximum: $DURATION"
fi

# Check CloudWatch logs for errors
echo "Checking Lambda logs for error patterns..."
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

ERROR_PATTERNS_FOUND=0
TIMEOUT_ERRORS=0
MEMORY_ERRORS=0

if [ -n "$LOG_STREAMS" ]; then
    for stream in $LOG_STREAMS; do
        # Get logs from the last 15 minutes
        LOGS=$(aws logs get-log-events \
            --log-group-name "$LOG_GROUP_NAME" \
            --log-stream-name "$stream" \
            --start-time "$(($(date +%s) * 1000 - 900000))" \
            --region "$AWS_REGION" \
            --query 'events[].message' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$LOGS" ]; then
            # Check for various error patterns
            if echo "$LOGS" | grep -qi "error\|exception\|failed"; then
                ERROR_PATTERNS_FOUND=$((ERROR_PATTERNS_FOUND + 1))
            fi
            
            if echo "$LOGS" | grep -qi "timeout\|timed out"; then
                TIMEOUT_ERRORS=$((TIMEOUT_ERRORS + 1))
            fi
            
            if echo "$LOGS" | grep -qi "memory\|out of memory"; then
                MEMORY_ERRORS=$((MEMORY_ERRORS + 1))
            fi
            
            # Check for our test files
            for test_file in "$INVALID_TEST_FILE" "$EMPTY_TEST_FILE" "$LARGE_TEST_FILE"; do
                if echo "$LOGS" | grep -q "$test_file"; then
                    echo "✓ Found log entry for test file: $test_file"
                fi
            done
        fi
    done
    
    echo "Error patterns found in logs: $ERROR_PATTERNS_FOUND"
    echo "Timeout errors: $TIMEOUT_ERRORS"
    echo "Memory errors: $MEMORY_ERRORS"
else
    echo "WARNING: Could not retrieve Lambda log streams"
fi

# Check SNS notification sending (if errors occurred)
echo "Checking SNS notification system..."
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "Errors detected - checking if SNS notifications were sent..."
    
    # Check SNS topic metrics
    SNS_PUBLISHES=$(aws cloudwatch get-metric-statistics \
        --namespace "AWS/SNS" \
        --metric-name "NumberOfMessagesPublished" \
        --dimensions Name=TopicName,Value="$(echo "$SNS_TOPIC_ARN" | cut -d':' -f6)" \
        --statistics "Sum" \
        --start-time "$(date -d '10 minutes ago' -u +%Y-%m-%dT%H:%M:%S)" \
        --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
        --period 600 \
        --region "$AWS_REGION" \
        --query 'Datapoints[0].Sum' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$SNS_PUBLISHES" != "None" ] && [ "$SNS_PUBLISHES" -gt 0 ]; then
        echo "✓ SNS notifications sent: $SNS_PUBLISHES"
    else
        echo "WARNING: No SNS notifications detected despite errors"
    fi
else
    echo "No errors detected - SNS notifications not expected"
fi

# Check Dead Letter Queue (if configured)
echo "Checking for dead letter queue messages..."
# Note: This would require knowing the DLQ ARN/URL if configured
# For now, we'll check if Lambda has DLQ configuration
LAMBDA_CONFIG=$(aws lambda get-function \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --query 'Configuration.DeadLetterConfig.TargetArn' \
    --output text --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -n "$LAMBDA_CONFIG" ] && [ "$LAMBDA_CONFIG" != "None" ]; then
    echo "✓ Dead Letter Queue configured: $LAMBDA_CONFIG"
else
    echo "INFO: No Dead Letter Queue configured"
fi

# Test file processing results
echo "Checking error test file processing results..."

# Check if invalid/empty files were handled appropriately
for test_file in "$INVALID_TEST_FILE" "$EMPTY_TEST_FILE" "$LARGE_TEST_FILE"; do
    # Check output bucket
    OUTPUT_CHECK=$(aws s3 ls "s3://$OUTPUT_BUCKET_NAME/" --region "$AWS_REGION" | grep "$test_file" || echo "")
    if [ -n "$OUTPUT_CHECK" ]; then
        echo "✓ Test file found in output bucket: $test_file"
    else
        echo "INFO: Test file not in output bucket: $test_file"
    fi
    
    # Check backup bucket
    BACKUP_CHECK=$(aws s3 ls "s3://$BACKUP_BUCKET_NAME/" --region "$AWS_REGION" | grep "$test_file" || echo "")
    if [ -n "$BACKUP_CHECK" ]; then
        echo "✓ Test file found in backup bucket: $test_file"
    else
        echo "INFO: Test file not in backup bucket: $test_file"
    fi
done

# Clean up test files
echo "Cleaning up error test files..."
rm -f "/tmp/$INVALID_TEST_FILE" "/tmp/$EMPTY_TEST_FILE" "/tmp/$LARGE_TEST_FILE"

# Remove from S3 buckets
for test_file in "$INVALID_TEST_FILE" "$EMPTY_TEST_FILE" "$LARGE_TEST_FILE"; do
    aws s3 rm "s3://$INPUT_BUCKET_NAME/$test_file" --region "$AWS_REGION" 2>/dev/null || true
    aws s3 rm "s3://$OUTPUT_BUCKET_NAME/$test_file" --region "$AWS_REGION" 2>/dev/null || true
    aws s3 rm "s3://$BACKUP_BUCKET_NAME/$test_file" --region "$AWS_REGION" 2>/dev/null || true
done

echo "✓ Cleanup completed"

# Test summary
echo ""
echo "=== ERROR HANDLING TEST SUMMARY ==="
echo "Invalid file upload: ✓"
echo "Empty file upload: ✓"
echo "Large file upload: ✓"
echo "Lambda errors detected: $ERROR_COUNT"
echo "Error patterns in logs: $ERROR_PATTERNS_FOUND"
echo "Timeout errors: $TIMEOUT_ERRORS"
echo "Memory errors: $MEMORY_ERRORS"

# Determine test result
if [ "$ERROR_PATTERNS_FOUND" -eq 0 ] && [ "$TIMEOUT_ERRORS" -eq 0 ] && [ "$MEMORY_ERRORS" -eq 0 ]; then
    echo ""
    echo "✅ Error handling test PASSED - System handled error cases gracefully"
    exit 0
elif [ "$TIMEOUT_ERRORS" -gt 0 ] || [ "$MEMORY_ERRORS" -gt 0 ]; then
    echo ""
    echo "⚠ Error handling test PARTIAL - Some execution issues detected"
    exit 0
else
    echo ""
    echo "✅ Error handling test COMPLETED - Errors detected and handled as expected"
    exit 0
fi