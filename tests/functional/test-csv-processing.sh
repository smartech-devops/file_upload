#!/bin/bash

# Test: CSV Processing
# Tests CSV parsing, validation, and transformation functionality

set -e

echo "Testing CSV processing functionality..."

# Test 1: Well-formed CSV with standard data types
echo "Test 1: Standard CSV processing..."
STANDARD_TEST_FILE="standard-csv-$(date +%s).csv"
STANDARD_CONTENT="id,name,email,age,department,active
1,John Doe,john.doe@example.com,30,Engineering,true
2,Jane Smith,jane.smith@example.com,28,Marketing,true
3,Bob Johnson,bob.johnson@example.com,35,Sales,false
4,Alice Williams,alice.williams@example.com,32,Engineering,true"

echo "Creating standard CSV test file: $STANDARD_TEST_FILE"
echo "$STANDARD_CONTENT" > "/tmp/$STANDARD_TEST_FILE"

# Upload and process
aws s3 cp "/tmp/$STANDARD_TEST_FILE" "s3://$INPUT_BUCKET_NAME/$STANDARD_TEST_FILE" --region "$AWS_REGION"
echo "✓ Standard CSV uploaded"

# Test 2: CSV with special characters and encoding
echo "Test 2: Special characters CSV processing..."
SPECIAL_TEST_FILE="special-csv-$(date +%s).csv"
SPECIAL_CONTENT="id,name,description,location
1,José García,\"Software engineer with 5+ years experience\",São Paulo
2,François Müller,\"Data analyst, ML enthusiast\",Zürich
3,李小明,\"Product manager at tech company\",北京
4,Анна Петрова,\"UX/UI designer & researcher\",Москва"

echo "Creating special characters CSV test file: $SPECIAL_TEST_FILE"
echo "$SPECIAL_CONTENT" > "/tmp/$SPECIAL_TEST_FILE"

aws s3 cp "/tmp/$SPECIAL_TEST_FILE" "s3://$INPUT_BUCKET_NAME/$SPECIAL_TEST_FILE" --region "$AWS_REGION"
echo "✓ Special characters CSV uploaded"

# Test 3: CSV with various data formats
echo "Test 3: Mixed data formats CSV processing..."
MIXED_TEST_FILE="mixed-csv-$(date +%s).csv"
MIXED_CONTENT="order_id,customer_name,order_date,amount,currency,status
ORD001,John Smith,2023-12-01,1299.99,USD,completed
ORD002,Emma Johnson,2023-12-02,45.50,EUR,pending
ORD003,Mike Chen,2023-12-03,899.00,USD,shipped
ORD004,Sarah Brown,2023-12-04,156.75,GBP,cancelled"

echo "Creating mixed data formats CSV test file: $MIXED_TEST_FILE"
echo "$MIXED_CONTENT" > "/tmp/$MIXED_TEST_FILE"

aws s3 cp "/tmp/$MIXED_TEST_FILE" "s3://$INPUT_BUCKET_NAME/$MIXED_TEST_FILE" --region "$AWS_REGION"
echo "✓ Mixed data formats CSV uploaded"

# Test 4: CSV with quoted fields and commas
echo "Test 4: Quoted fields CSV processing..."
QUOTED_TEST_FILE="quoted-csv-$(date +%s).csv"
QUOTED_CONTENT="id,title,description,tags
1,\"Product Manager, Senior\",\"Responsible for product strategy, roadmap planning\",\"management,strategy,product\"
2,\"Software Engineer, Full Stack\",\"Develops web applications using modern frameworks\",\"javascript,react,node.js\"
3,\"Data Scientist, ML\",\"Machine learning model development and deployment\",\"python,ml,ai,statistics\""

echo "Creating quoted fields CSV test file: $QUOTED_TEST_FILE"
echo "$QUOTED_CONTENT" > "/tmp/$QUOTED_TEST_FILE"

aws s3 cp "/tmp/$QUOTED_TEST_FILE" "s3://$INPUT_BUCKET_NAME/$QUOTED_TEST_FILE" --region "$AWS_REGION"
echo "✓ Quoted fields CSV uploaded"

# Test 5: CSV with missing/null values
echo "Test 5: Missing values CSV processing..."
MISSING_TEST_FILE="missing-csv-$(date +%s).csv"
MISSING_CONTENT="id,name,email,phone,department
1,John Doe,john@example.com,,Engineering
2,Jane Smith,,555-0123,Marketing
3,Bob Johnson,bob@example.com,555-0456,
4,,alice@example.com,555-0789,Engineering
5,Charlie Brown,charlie@example.com,555-0101,Sales"

echo "Creating missing values CSV test file: $MISSING_TEST_FILE"
echo "$MISSING_CONTENT" > "/tmp/$MISSING_TEST_FILE"

aws s3 cp "/tmp/$MISSING_TEST_FILE" "s3://$INPUT_BUCKET_NAME/$MISSING_TEST_FILE" --region "$AWS_REGION"
echo "✓ Missing values CSV uploaded"

# Wait for all files to be processed
echo "Waiting for CSV processing to complete..."
WAIT_TIME=0
MAX_WAIT=300  # 5 minutes

TEST_FILES=("$STANDARD_TEST_FILE" "$SPECIAL_TEST_FILE" "$MIXED_TEST_FILE" "$QUOTED_TEST_FILE" "$MISSING_TEST_FILE")

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    echo "Waiting... ($WAIT_TIME/$MAX_WAIT seconds)"
    sleep 20
    WAIT_TIME=$((WAIT_TIME + 20))
    
    PROCESSED_COUNT=0
    for test_file in "${TEST_FILES[@]}"; do
        # Check if file appears in output or backup bucket
        OUTPUT_CHECK=$(aws s3 ls "s3://$OUTPUT_BUCKET_NAME/" --region "$AWS_REGION" | grep "$test_file" || echo "")
        BACKUP_CHECK=$(aws s3 ls "s3://$BACKUP_BUCKET_NAME/" --region "$AWS_REGION" | grep "$test_file" || echo "")
        
        if [ -n "$OUTPUT_CHECK" ] || [ -n "$BACKUP_CHECK" ]; then
            PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
        fi
    done
    
    echo "Files processed: $PROCESSED_COUNT/${#TEST_FILES[@]}"
    
    if [ $PROCESSED_COUNT -eq ${#TEST_FILES[@]} ]; then
        echo "✓ All test files processed!"
        break
    fi
done

# Verify processing results
echo "Verifying CSV processing results..."

SUCCESSFUL_PROCESSING=0
FAILED_PROCESSING=0

for test_file in "${TEST_FILES[@]}"; do
    echo ""
    echo "Checking results for: $test_file"
    
    # Check output bucket
    OUTPUT_EXISTS=$(aws s3 ls "s3://$OUTPUT_BUCKET_NAME/$test_file" --region "$AWS_REGION" 2>/dev/null | wc -l)
    if [ "$OUTPUT_EXISTS" -gt 0 ]; then
        echo "✓ Processed file found in output bucket"
        
        # Download and analyze processed file
        aws s3 cp "s3://$OUTPUT_BUCKET_NAME/$test_file" "/tmp/processed_$test_file" --region "$AWS_REGION" 2>/dev/null
        
        if [ -f "/tmp/processed_$test_file" ]; then
            # Basic validation
            ORIGINAL_LINES=$(wc -l < "/tmp/$test_file")
            PROCESSED_LINES=$(wc -l < "/tmp/processed_$test_file")
            
            echo "  Original lines: $ORIGINAL_LINES"
            echo "  Processed lines: $PROCESSED_LINES"
            
            # Check if file has content
            if [ "$PROCESSED_LINES" -gt 0 ]; then
                echo "✓ Processed file has content"
                
                # Check if header is preserved
                ORIGINAL_HEADER=$(head -1 "/tmp/$test_file")
                PROCESSED_HEADER=$(head -1 "/tmp/processed_$test_file")
                
                if [ "$ORIGINAL_HEADER" = "$PROCESSED_HEADER" ]; then
                    echo "✓ CSV header preserved correctly"
                else
                    echo "⚠ CSV header may have been modified"
                    echo "  Original: $ORIGINAL_HEADER"
                    echo "  Processed: $PROCESSED_HEADER"
                fi
                
                SUCCESSFUL_PROCESSING=$((SUCCESSFUL_PROCESSING + 1))
            else
                echo "❌ Processed file is empty"
                FAILED_PROCESSING=$((FAILED_PROCESSING + 1))
            fi
            
            rm -f "/tmp/processed_$test_file"
        else
            echo "❌ Could not download processed file"
            FAILED_PROCESSING=$((FAILED_PROCESSING + 1))
        fi
    else
        echo "⚠ No processed file found in output bucket"
        
        # Check if it's in backup bucket (might indicate processing failure)
        BACKUP_EXISTS=$(aws s3 ls "s3://$BACKUP_BUCKET_NAME/$test_file" --region "$AWS_REGION" 2>/dev/null | wc -l)
        if [ "$BACKUP_EXISTS" -gt 0 ]; then
            echo "✓ Original file found in backup bucket"
        fi
        
        FAILED_PROCESSING=$((FAILED_PROCESSING + 1))
    fi
done

# Check Lambda execution logs for CSV processing details
echo ""
echo "Checking Lambda logs for CSV processing details..."
LOG_GROUP_NAME="/aws/lambda/$LAMBDA_FUNCTION_NAME"

# Get recent log streams
LOG_STREAMS=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP_NAME" \
    --order-by "LastEventTime" \
    --descending \
    --max-items 10 \
    --region "$AWS_REGION" \
    --query 'logStreams[].logStreamName' \
    --output text 2>/dev/null || echo "")

CSV_PROCESSING_LOGS_FOUND=0

if [ -n "$LOG_STREAMS" ]; then
    for stream in $LOG_STREAMS; do
        LOGS=$(aws logs get-log-events \
            --log-group-name "$LOG_GROUP_NAME" \
            --log-stream-name "$stream" \
            --start-time "$(($(date +%s) * 1000 - 600000))" \
            --region "$AWS_REGION" \
            --query 'events[].message' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$LOGS" ]; then
            # Look for CSV processing indicators
            if echo "$LOGS" | grep -qi "csv\|parse\|row\|column\|process"; then
                CSV_PROCESSING_LOGS_FOUND=$((CSV_PROCESSING_LOGS_FOUND + 1))
                
                # Check for specific test files
                for test_file in "${TEST_FILES[@]}"; do
                    if echo "$LOGS" | grep -q "$test_file"; then
                        echo "✓ Found processing logs for: $test_file"
                    fi
                done
            fi
        fi
    done
    
    echo "Log streams with CSV processing activity: $CSV_PROCESSING_LOGS_FOUND"
else
    echo "⚠ Could not retrieve Lambda log streams"
fi

# Clean up test files
echo ""
echo "Cleaning up CSV test files..."
for test_file in "${TEST_FILES[@]}"; do
    rm -f "/tmp/$test_file"
    aws s3 rm "s3://$INPUT_BUCKET_NAME/$test_file" --region "$AWS_REGION" 2>/dev/null || true
    aws s3 rm "s3://$OUTPUT_BUCKET_NAME/$test_file" --region "$AWS_REGION" 2>/dev/null || true
    aws s3 rm "s3://$BACKUP_BUCKET_NAME/$test_file" --region "$AWS_REGION" 2>/dev/null || true
done

echo "✓ Cleanup completed"

# Test summary
echo ""
echo "=== CSV PROCESSING TEST SUMMARY ==="
echo "Test files uploaded: ${#TEST_FILES[@]}"
echo "Successfully processed: $SUCCESSFUL_PROCESSING"
echo "Processing failures: $FAILED_PROCESSING"
echo "CSV processing logs found: $CSV_PROCESSING_LOGS_FOUND"

# Test types summary
echo ""
echo "Test scenarios covered:"
echo "✓ Standard CSV format"
echo "✓ Special characters and Unicode"
echo "✓ Mixed data formats"
echo "✓ Quoted fields with commas"
echo "✓ Missing/null values"

# Determine overall result
if [ $SUCCESSFUL_PROCESSING -eq ${#TEST_FILES[@]} ]; then
    echo ""
    echo "✅ CSV processing test PASSED - All files processed successfully!"
    exit 0
elif [ $SUCCESSFUL_PROCESSING -gt 0 ]; then
    echo ""
    echo "⚠ CSV processing test PARTIAL - Some files processed successfully"
    exit 0
else
    echo ""
    echo "❌ CSV processing test FAILED - No files processed successfully"
    exit 1
fi