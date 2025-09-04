#!/bin/bash

# Test: End-to-End Workflow
# Tests complete CSV processing workflow from S3 upload to final output

set -e

echo "Testing end-to-end CSV processing workflow..."

# Generate comprehensive test CSV file
TEST_FILE="e2e-test-$(date +%s).csv"
TEST_CONTENT="id,first_name,last_name,email,age,department,salary
1,John,Doe,john.doe@example.com,30,Engineering,75000
2,Jane,Smith,jane.smith@example.com,28,Marketing,65000
3,Bob,Johnson,bob.johnson@example.com,35,Sales,70000
4,Alice,Williams,alice.williams@example.com,32,Engineering,80000
5,Charlie,Brown,charlie.brown@example.com,29,HR,60000"

echo "Creating test CSV file: $TEST_FILE"
echo "$TEST_CONTENT" > "/tmp/$TEST_FILE"

# Display test file for verification
echo "Test file content:"
cat "/tmp/$TEST_FILE"
echo ""

# Upload test file to S3 input bucket
echo "Step 1: Uploading CSV file to input bucket..."
UPLOAD_TIME=$(date +%s)
aws s3 cp "/tmp/$TEST_FILE" "s3://$INPUT_BUCKET_NAME/$TEST_FILE" --region "$AWS_REGION"

if [ $? -eq 0 ]; then
    echo "✓ File uploaded successfully to input bucket"
else
    echo "ERROR: Failed to upload file to input bucket"
    exit 1
fi

# Wait for processing to complete
echo "Step 2: Waiting for Lambda processing..."
WAIT_TIME=0
MAX_WAIT=180  # 3 minutes max wait

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    echo "Waiting... ($WAIT_TIME/$MAX_WAIT seconds)"
    sleep 15
    WAIT_TIME=$((WAIT_TIME + 15))
    
    # Check if file has been processed (appears in output or backup bucket)
    OUTPUT_CHECK=$(aws s3 ls "s3://$OUTPUT_BUCKET_NAME/" --region "$AWS_REGION" | grep "$TEST_FILE" || echo "")
    BACKUP_CHECK=$(aws s3 ls "s3://$BACKUP_BUCKET_NAME/" --region "$AWS_REGION" | grep "$TEST_FILE" || echo "")
    
    if [ -n "$OUTPUT_CHECK" ] || [ -n "$BACKUP_CHECK" ]; then
        echo "✓ File processing detected!"
        break
    fi
done

# Check processing results
echo "Step 3: Verifying processing results..."

# Check if original file was moved/copied to backup bucket
echo "Checking backup bucket..."
BACKUP_FILES=$(aws s3 ls "s3://$BACKUP_BUCKET_NAME/" --region "$AWS_REGION" | grep "$TEST_FILE" || echo "")
if [ -n "$BACKUP_FILES" ]; then
    echo "✓ Original file backed up successfully"
    BACKUP_SUCCESS=true
else
    echo "WARNING: Original file not found in backup bucket"
    BACKUP_SUCCESS=false
fi

# Check if processed file exists in output bucket
echo "Checking output bucket..."
OUTPUT_FILES=$(aws s3 ls "s3://$OUTPUT_BUCKET_NAME/" --region "$AWS_REGION" | grep "$TEST_FILE" || echo "")
if [ -n "$OUTPUT_FILES" ]; then
    echo "✓ Processed file found in output bucket"
    
    # Download and verify processed file
    aws s3 cp "s3://$OUTPUT_BUCKET_NAME/$TEST_FILE" "/tmp/processed_$TEST_FILE" --region "$AWS_REGION"
    
    if [ -f "/tmp/processed_$TEST_FILE" ]; then
        echo "✓ Successfully downloaded processed file"
        
        echo "Processed file content:"
        cat "/tmp/processed_$TEST_FILE"
        echo ""
        
        # Basic validation of processed file
        PROCESSED_LINES=$(wc -l < "/tmp/processed_$TEST_FILE")
        ORIGINAL_LINES=$(wc -l < "/tmp/$TEST_FILE")
        
        if [ "$PROCESSED_LINES" -eq "$ORIGINAL_LINES" ]; then
            echo "✓ Processed file has same number of lines as original"
        else
            echo "WARNING: Line count mismatch - Original: $ORIGINAL_LINES, Processed: $PROCESSED_LINES"
        fi
        
        OUTPUT_SUCCESS=true
        rm -f "/tmp/processed_$TEST_FILE"
    else
        echo "ERROR: Could not download processed file"
        OUTPUT_SUCCESS=false
    fi
else
    echo "WARNING: Processed file not found in output bucket"
    OUTPUT_SUCCESS=false
fi

# Check if original file was removed from input bucket
echo "Checking input bucket cleanup..."
INPUT_CHECK=$(aws s3 ls "s3://$INPUT_BUCKET_NAME/" --region "$AWS_REGION" | grep "$TEST_FILE" || echo "")
if [ -z "$INPUT_CHECK" ]; then
    echo "✓ Original file removed from input bucket"
    INPUT_CLEANUP=true
else
    echo "WARNING: Original file still exists in input bucket"
    INPUT_CLEANUP=false
fi

# Check Lambda execution logs
echo "Step 4: Checking Lambda execution logs..."
LOG_GROUP_NAME="/aws/lambda/$LAMBDA_FUNCTION_NAME"

# Find log streams from the time of upload
LOG_STREAMS=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP_NAME" \
    --order-by "LastEventTime" \
    --descending \
    --max-items 3 \
    --region "$AWS_REGION" \
    --query 'logStreams[].logStreamName' \
    --output text 2>/dev/null || echo "")

EXECUTION_FOUND=false
ERROR_FOUND=false

if [ -n "$LOG_STREAMS" ]; then
    for stream in $LOG_STREAMS; do
        # Get logs from around the upload time
        LOGS=$(aws logs get-log-events \
            --log-group-name "$LOG_GROUP_NAME" \
            --log-stream-name "$stream" \
            --start-time "$((UPLOAD_TIME * 1000 - 60000))" \
            --region "$AWS_REGION" \
            --query 'events[].message' \
            --output text 2>/dev/null || echo "")
        
        if echo "$LOGS" | grep -q "$TEST_FILE"; then
            echo "✓ Found Lambda execution for test file"
            EXECUTION_FOUND=true
            
            # Check for errors in this execution
            if echo "$LOGS" | grep -qi "error\|exception\|failed"; then
                echo "WARNING: Errors found in Lambda execution:"
                echo "$LOGS" | grep -i "error\|exception\|failed" | head -3
                ERROR_FOUND=true
            fi
            break
        fi
    done
else
    echo "WARNING: Could not retrieve Lambda log streams"
fi

if [ "$EXECUTION_FOUND" = false ]; then
    echo "WARNING: No Lambda execution found for test file"
fi

# Check CloudWatch metrics
echo "Step 5: Checking CloudWatch metrics..."

# Check Lambda invocations
INVOCATIONS=$(aws cloudwatch get-metric-statistics \
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

if [ "$INVOCATIONS" != "None" ] && [ "$INVOCATIONS" -gt 0 ]; then
    echo "✓ Lambda invocations detected: $INVOCATIONS"
else
    echo "WARNING: No Lambda invocations found in CloudWatch metrics"
fi

# Check Lambda errors
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
    echo "WARNING: Lambda errors detected: $ERROR_COUNT"
else
    echo "✓ No Lambda errors in CloudWatch metrics"
fi

# Clean up test files
echo "Step 6: Cleaning up test files..."
rm -f "/tmp/$TEST_FILE"
aws s3 rm "s3://$INPUT_BUCKET_NAME/$TEST_FILE" --region "$AWS_REGION" 2>/dev/null || true
aws s3 rm "s3://$OUTPUT_BUCKET_NAME/$TEST_FILE" --region "$AWS_REGION" 2>/dev/null || true
aws s3 rm "s3://$BACKUP_BUCKET_NAME/$TEST_FILE" --region "$AWS_REGION" 2>/dev/null || true

echo "✓ Cleanup completed"

# Generate test summary
echo ""
echo "=== END-TO-END TEST SUMMARY ==="
echo "File upload: ✓"
echo "Lambda execution: $([ "$EXECUTION_FOUND" = true ] && echo "✓" || echo "⚠")"
echo "Backup creation: $([ "$BACKUP_SUCCESS" = true ] && echo "✓" || echo "⚠")"
echo "Output generation: $([ "$OUTPUT_SUCCESS" = true ] && echo "✓" || echo "⚠")"
echo "Input cleanup: $([ "$INPUT_CLEANUP" = true ] && echo "✓" || echo "⚠")"
echo "Error-free execution: $([ "$ERROR_FOUND" = false ] && echo "✓" || echo "⚠")"

# Determine overall test result
if [ "$OUTPUT_SUCCESS" = true ] && [ "$BACKUP_SUCCESS" = true ] && [ "$ERROR_FOUND" = false ]; then
    echo ""
    echo "✅ End-to-end workflow test PASSED!"
    exit 0
elif [ "$OUTPUT_SUCCESS" = true ] || [ "$BACKUP_SUCCESS" = true ]; then
    echo ""
    echo "⚠ End-to-end workflow test PARTIALLY PASSED"
    exit 0
else
    echo ""
    echo "❌ End-to-end workflow test FAILED"
    exit 1
fi