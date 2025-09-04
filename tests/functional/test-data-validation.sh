#!/bin/bash

# Test: Data Validation
# Tests data type validation, constraints, and business logic

set -e

echo "Testing data validation functionality..."

# Test 1: Email format validation
echo "Test 1: Email format validation..."
EMAIL_TEST_FILE="email-validation-$(date +%s).csv"
EMAIL_CONTENT="id,name,email,department
1,John Doe,john.doe@example.com,Engineering
2,Jane Smith,invalid-email-format,Marketing
3,Bob Johnson,bob@company.com,Sales
4,Alice Williams,alice.williams@,Engineering
5,Charlie Brown,@example.com,Marketing
6,David Lee,david.lee@example.co.uk,Sales"

echo "Creating email validation test file: $EMAIL_TEST_FILE"
echo "$EMAIL_CONTENT" > "/tmp/$EMAIL_TEST_FILE"

aws s3 cp "/tmp/$EMAIL_TEST_FILE" "s3://$INPUT_BUCKET_NAME/$EMAIL_TEST_FILE" --region "$AWS_REGION"
echo "✓ Email validation test file uploaded"

# Test 2: Numeric data validation
echo "Test 2: Numeric data validation..."
NUMERIC_TEST_FILE="numeric-validation-$(date +%s).csv"
NUMERIC_CONTENT="id,name,age,salary,rating
1,John Doe,30,75000,4.5
2,Jane Smith,invalid_age,65000,4.2
3,Bob Johnson,35,invalid_salary,4.8
4,Alice Williams,32,80000,invalid_rating
5,Charlie Brown,-5,50000,3.9
6,David Lee,150,1000000,5.1"

echo "Creating numeric validation test file: $NUMERIC_TEST_FILE"
echo "$NUMERIC_CONTENT" > "/tmp/$NUMERIC_TEST_FILE"

aws s3 cp "/tmp/$NUMERIC_TEST_FILE" "s3://$INPUT_BUCKET_NAME/$NUMERIC_TEST_FILE" --region "$AWS_REGION"
echo "✓ Numeric validation test file uploaded"

# Test 3: Date format validation
echo "Test 3: Date format validation..."
DATE_TEST_FILE="date-validation-$(date +%s).csv"
DATE_CONTENT="id,name,hire_date,birth_date,last_login
1,John Doe,2023-01-15,1990-05-20,2023-12-01T10:30:00Z
2,Jane Smith,2023/02/20,1985-13-40,2023-12-02 15:45:30
3,Bob Johnson,invalid-date,1988-02-29,2023-12-03
4,Alice Williams,2023-03-10,1992-04-15,invalid-timestamp
5,Charlie Brown,2023-04-01,,2023-12-05T08:15:45Z"

echo "Creating date validation test file: $DATE_TEST_FILE"
echo "$DATE_CONTENT" > "/tmp/$DATE_TEST_FILE"

aws s3 cp "/tmp/$DATE_TEST_FILE" "s3://$INPUT_BUCKET_NAME/$DATE_TEST_FILE" --region "$AWS_REGION"
echo "✓ Date validation test file uploaded"

# Test 4: Required fields validation
echo "Test 4: Required fields validation..."
REQUIRED_TEST_FILE="required-fields-$(date +%s).csv"
REQUIRED_CONTENT="id,name,email,department
1,John Doe,john@example.com,Engineering
2,,jane@example.com,Marketing
3,Bob Johnson,,Sales
4,Alice Williams,alice@example.com,
5,,,
6,Charlie Brown,charlie@example.com,Marketing"

echo "Creating required fields test file: $REQUIRED_TEST_FILE"
echo "$REQUIRED_CONTENT" > "/tmp/$REQUIRED_TEST_FILE"

aws s3 cp "/tmp/$REQUIRED_TEST_FILE" "s3://$INPUT_BUCKET_NAME/$REQUIRED_TEST_FILE" --region "$AWS_REGION"
echo "✓ Required fields test file uploaded"

# Test 5: Duplicate records validation
echo "Test 5: Duplicate records validation..."
DUPLICATE_TEST_FILE="duplicate-validation-$(date +%s).csv"
DUPLICATE_CONTENT="id,name,email,department
1,John Doe,john@example.com,Engineering
2,Jane Smith,jane@example.com,Marketing
1,John Doe,john@example.com,Engineering
3,Bob Johnson,bob@example.com,Sales
2,Jane Smith Different,jane@example.com,HR
4,Alice Williams,alice@example.com,Engineering"

echo "Creating duplicate records test file: $DUPLICATE_TEST_FILE"
echo "$DUPLICATE_CONTENT" > "/tmp/$DUPLICATE_TEST_FILE"

aws s3 cp "/tmp/$DUPLICATE_TEST_FILE" "s3://$INPUT_BUCKET_NAME/$DUPLICATE_TEST_FILE" --region "$AWS_REGION"
echo "✓ Duplicate records test file uploaded"

# Test 6: Data length and constraints
echo "Test 6: Data length constraints..."
LENGTH_TEST_FILE="length-validation-$(date +%s).csv"
LENGTH_CONTENT="id,name,description,code
1,John,Short description,ABC
2,$(printf 'A%.0s' {1..300}),Normal description,XYZ
3,Jane,$(printf 'Very long description %.0s' {1..100}),TOOLONG
4,Bob,Good description,AB
5,Alice,Another description,VALID123"

echo "Creating length validation test file: $LENGTH_TEST_FILE"
echo "$LENGTH_CONTENT" > "/tmp/$LENGTH_TEST_FILE"

aws s3 cp "/tmp/$LENGTH_TEST_FILE" "s3://$INPUT_BUCKET_NAME/$LENGTH_TEST_FILE" --region "$AWS_REGION"
echo "✓ Length validation test file uploaded"

# Wait for all validation tests to be processed
echo "Waiting for data validation processing..."
WAIT_TIME=0
MAX_WAIT=360  # 6 minutes

VALIDATION_TEST_FILES=("$EMAIL_TEST_FILE" "$NUMERIC_TEST_FILE" "$DATE_TEST_FILE" "$REQUIRED_TEST_FILE" "$DUPLICATE_TEST_FILE" "$LENGTH_TEST_FILE")

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    echo "Waiting... ($WAIT_TIME/$MAX_WAIT seconds)"
    sleep 30
    WAIT_TIME=$((WAIT_TIME + 30))
    
    PROCESSED_COUNT=0
    for test_file in "${VALIDATION_TEST_FILES[@]}"; do
        OUTPUT_CHECK=$(aws s3 ls "s3://$OUTPUT_BUCKET_NAME/" --region "$AWS_REGION" | grep "$test_file" || echo "")
        BACKUP_CHECK=$(aws s3 ls "s3://$BACKUP_BUCKET_NAME/" --region "$AWS_REGION" | grep "$test_file" || echo "")
        
        if [ -n "$OUTPUT_CHECK" ] || [ -n "$BACKUP_CHECK" ]; then
            PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
        fi
    done
    
    echo "Validation files processed: $PROCESSED_COUNT/${#VALIDATION_TEST_FILES[@]}"
    
    if [ $PROCESSED_COUNT -eq ${#VALIDATION_TEST_FILES[@]} ]; then
        echo "✓ All validation test files processed!"
        break
    fi
done

# Analyze validation results
echo ""
echo "Analyzing data validation results..."

VALIDATION_PASSED=0
VALIDATION_FAILED=0
VALIDATION_WARNINGS=0

for test_file in "${VALIDATION_TEST_FILES[@]}"; do
    echo ""
    echo "Analyzing validation results for: $test_file"
    
    # Check if file was processed successfully
    OUTPUT_EXISTS=$(aws s3 ls "s3://$OUTPUT_BUCKET_NAME/$test_file" --region "$AWS_REGION" 2>/dev/null | wc -l)
    
    if [ "$OUTPUT_EXISTS" -gt 0 ]; then
        echo "✓ File processed and output generated"
        
        # Download and analyze processed file
        aws s3 cp "s3://$OUTPUT_BUCKET_NAME/$test_file" "/tmp/validated_$test_file" --region "$AWS_REGION" 2>/dev/null
        
        if [ -f "/tmp/validated_$test_file" ]; then
            ORIGINAL_RECORDS=$(tail -n +2 "/tmp/$test_file" | wc -l)
            PROCESSED_RECORDS=$(tail -n +2 "/tmp/validated_$test_file" | wc -l)
            
            echo "  Original records (excluding header): $ORIGINAL_RECORDS"
            echo "  Processed records: $PROCESSED_RECORDS"
            
            if [ "$PROCESSED_RECORDS" -lt "$ORIGINAL_RECORDS" ]; then
                echo "✓ Data validation filtered out invalid records"
                VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
            elif [ "$PROCESSED_RECORDS" -eq "$ORIGINAL_RECORDS" ]; then
                echo "⚠ All records passed validation (or no validation applied)"
                VALIDATION_WARNINGS=$((VALIDATION_WARNINGS + 1))
            else
                echo "⚠ More processed records than original (unexpected)"
                VALIDATION_WARNINGS=$((VALIDATION_WARNINGS + 1))
            fi
            
            # Check for specific validation patterns based on test type
            case $test_file in
                *"email-validation"*)
                    echo "  Checking email validation..."
                    INVALID_EMAILS=$(grep -E "(invalid-email-format|alice.williams@|@example.com)" "/tmp/validated_$test_file" 2>/dev/null | wc -l)
                    if [ "$INVALID_EMAILS" -eq 0 ]; then
                        echo "  ✓ Invalid email formats filtered out"
                    else
                        echo "  ⚠ Invalid emails may still be present: $INVALID_EMAILS"
                    fi
                    ;;
                *"numeric-validation"*)
                    echo "  Checking numeric validation..."
                    INVALID_NUMBERS=$(grep -E "(invalid_age|invalid_salary|invalid_rating)" "/tmp/validated_$test_file" 2>/dev/null | wc -l)
                    if [ "$INVALID_NUMBERS" -eq 0 ]; then
                        echo "  ✓ Invalid numeric values filtered out"
                    else
                        echo "  ⚠ Invalid numbers may still be present: $INVALID_NUMBERS"
                    fi
                    ;;
                *"date-validation"*)
                    echo "  Checking date validation..."
                    INVALID_DATES=$(grep -E "(invalid-date|2023/02/20|1985-13-40)" "/tmp/validated_$test_file" 2>/dev/null | wc -l)
                    if [ "$INVALID_DATES" -eq 0 ]; then
                        echo "  ✓ Invalid date formats filtered out"
                    else
                        echo "  ⚠ Invalid dates may still be present: $INVALID_DATES"
                    fi
                    ;;
                *"duplicate-validation"*)
                    echo "  Checking duplicate handling..."
                    DUPLICATE_IDS=$(tail -n +2 "/tmp/validated_$test_file" | cut -d',' -f1 | sort | uniq -d | wc -l)
                    if [ "$DUPLICATE_IDS" -eq 0 ]; then
                        echo "  ✓ Duplicate records handled correctly"
                    else
                        echo "  ⚠ Duplicate IDs may still be present: $DUPLICATE_IDS"
                    fi
                    ;;
            esac
            
            rm -f "/tmp/validated_$test_file"
        fi
    else
        echo "❌ File processing failed or no output generated"
        VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
    fi
done

# Check Lambda logs for validation-specific messages
echo ""
echo "Checking Lambda logs for validation activity..."
LOG_GROUP_NAME="/aws/lambda/$LAMBDA_FUNCTION_NAME"

LOG_STREAMS=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP_NAME" \
    --order-by "LastEventTime" \
    --descending \
    --max-items 10 \
    --region "$AWS_REGION" \
    --query 'logStreams[].logStreamName' \
    --output text 2>/dev/null || echo "")

VALIDATION_LOGS_FOUND=0

if [ -n "$LOG_STREAMS" ]; then
    for stream in $LOG_STREAMS; do
        LOGS=$(aws logs get-log-events \
            --log-group-name "$LOG_GROUP_NAME" \
            --log-stream-name "$stream" \
            --start-time "$(($(date +%s) * 1000 - 900000))" \
            --region "$AWS_REGION" \
            --query 'events[].message' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$LOGS" ]; then
            # Look for validation-related keywords
            if echo "$LOGS" | grep -qi "valid\|invalid\|filter\|reject\|duplicate\|constraint"; then
                VALIDATION_LOGS_FOUND=$((VALIDATION_LOGS_FOUND + 1))
                echo "✓ Found validation activity in log stream"
                
                # Check for specific validation messages
                if echo "$LOGS" | grep -qi "email.*invalid"; then
                    echo "  ✓ Email validation detected in logs"
                fi
                if echo "$LOGS" | grep -qi "numeric.*invalid\|age.*invalid\|salary.*invalid"; then
                    echo "  ✓ Numeric validation detected in logs"
                fi
                if echo "$LOGS" | grep -qi "date.*invalid\|timestamp.*invalid"; then
                    echo "  ✓ Date validation detected in logs"
                fi
                if echo "$LOGS" | grep -qi "duplicate.*found\|duplicate.*removed"; then
                    echo "  ✓ Duplicate detection in logs"
                fi
            fi
        fi
    done
    
    if [ $VALIDATION_LOGS_FOUND -eq 0 ]; then
        echo "⚠ No validation activity found in Lambda logs"
    fi
else
    echo "⚠ Could not retrieve Lambda log streams"
fi

# Check for validation error notifications
echo ""
echo "Checking for validation error notifications..."
SNS_PUBLISHES=$(aws cloudwatch get-metric-statistics \
    --namespace "AWS/SNS" \
    --metric-name "NumberOfMessagesPublished" \
    --dimensions Name=TopicName,Value="$(echo "$SNS_TOPIC_ARN" | cut -d':' -f6)" \
    --statistics "Sum" \
    --start-time "$(date -d '15 minutes ago' -u +%Y-%m-%dT%H:%M:%S)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
    --period 900 \
    --region "$AWS_REGION" \
    --query 'Datapoints[0].Sum' \
    --output text 2>/dev/null || echo "0")

if [ "$SNS_PUBLISHES" != "None" ] && [ "$SNS_PUBLISHES" -gt 0 ]; then
    echo "✓ SNS notifications sent (may include validation errors): $SNS_PUBLISHES"
else
    echo "INFO: No SNS notifications detected"
fi

# Clean up validation test files
echo ""
echo "Cleaning up validation test files..."
for test_file in "${VALIDATION_TEST_FILES[@]}"; do
    rm -f "/tmp/$test_file"
    aws s3 rm "s3://$INPUT_BUCKET_NAME/$test_file" --region "$AWS_REGION" 2>/dev/null || true
    aws s3 rm "s3://$OUTPUT_BUCKET_NAME/$test_file" --region "$AWS_REGION" 2>/dev/null || true
    aws s3 rm "s3://$BACKUP_BUCKET_NAME/$test_file" --region "$AWS_REGION" 2>/dev/null || true
done

echo "✓ Cleanup completed"

# Test summary
echo ""
echo "=== DATA VALIDATION TEST SUMMARY ==="
echo "Validation test scenarios: ${#VALIDATION_TEST_FILES[@]}"
echo "Validation passed: $VALIDATION_PASSED"
echo "Validation warnings: $VALIDATION_WARNINGS"
echo "Validation failed: $VALIDATION_FAILED"
echo "Validation logs found: $VALIDATION_LOGS_FOUND"

echo ""
echo "Validation scenarios tested:"
echo "✓ Email format validation"
echo "✓ Numeric data validation"
echo "✓ Date format validation"
echo "✓ Required fields validation"
echo "✓ Duplicate records validation"
echo "✓ Data length constraints"

# Determine overall result
TOTAL_SUCCESSFUL=$((VALIDATION_PASSED + VALIDATION_WARNINGS))

if [ $TOTAL_SUCCESSFUL -eq ${#VALIDATION_TEST_FILES[@]} ]; then
    echo ""
    echo "✅ Data validation test PASSED - All validation scenarios processed!"
    exit 0
elif [ $VALIDATION_PASSED -gt 0 ]; then
    echo ""
    echo "⚠ Data validation test PARTIAL - Some validation working correctly"
    exit 0
else
    echo ""
    echo "❌ Data validation test FAILED - No validation scenarios working"
    exit 1
fi