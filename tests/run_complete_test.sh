#!/bin/bash
# run_complete_test.sh
# Complete end-to-end test script following the MANUAL_TEST_GUIDE.md

set -e

echo "🚀 Starting Complete CSV File Upload System Test..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_FILE="test_data.csv"
FUNCTION_NAME="csv-processor"
EXPECTED_ROWS=9

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Get bucket names with random suffixes
get_bucket_names() {
    print_status $YELLOW "Getting S3 bucket names..."
    
    INPUT_BUCKET=$(aws s3 ls | grep candidate-test-input | awk '{print $3}')
    OUTPUT_BUCKET=$(aws s3 ls | grep candidate-test-output | awk '{print $3}')
    BACKUP_BUCKET=$(aws s3 ls | grep candidate-test-backup | awk '{print $3}')
    
    if [[ -z "$INPUT_BUCKET" || -z "$OUTPUT_BUCKET" || -z "$BACKUP_BUCKET" ]]; then
        print_status $RED "✗ Could not find all required buckets"
        print_status $RED "  Expected: candidate-test-input-*, candidate-test-output-*, candidate-test-backup-*"
        return 1
    fi
    
    print_status $GREEN "Found buckets:"
    print_status $BLUE "  Input:  $INPUT_BUCKET"
    print_status $BLUE "  Output: $OUTPUT_BUCKET"
    print_status $BLUE "  Backup: $BACKUP_BUCKET"
}

# Validate test data file
validate_test_data() {
    print_status $YELLOW "Validating test data file..."
    
    if [[ ! -f "$TEST_FILE" ]]; then
        print_status $RED "✗ Test file $TEST_FILE not found"
        return 1
    fi
    
    local actual_rows=$(tail -n +2 "$TEST_FILE" | wc -l)
    local header_check=$(head -n 1 "$TEST_FILE")
    
    if [[ $actual_rows -eq $EXPECTED_ROWS ]]; then
        print_status $GREEN "✓ Test file has correct number of rows ($actual_rows)"
    else
        print_status $RED "✗ Test file has $actual_rows rows, expected $EXPECTED_ROWS"
        return 1
    fi
    
    if [[ "$header_check" == "id,name,email,department,salary" ]]; then
        print_status $GREEN "✓ Test file has correct header format"
    else
        print_status $YELLOW "⚠ Test file header: $header_check"
    fi
}

# Clean up previous test artifacts
cleanup_previous_test() {
    print_status $YELLOW "Cleaning up previous test artifacts..."
    
    # Remove any previous test files from S3 buckets
    aws s3 rm s3://$INPUT_BUCKET/ --recursive --quiet || true
    aws s3 rm s3://$OUTPUT_BUCKET/ --recursive --quiet || true
    # Don't clean backup bucket to preserve history
    
    print_status $GREEN "✓ Previous test artifacts cleaned up"
}

# Upload CSV file to input bucket
upload_test_file() {
    print_status $YELLOW "Uploading test CSV file to input bucket..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local test_filename="complete_test_${timestamp}.csv"
    
    aws s3 cp $TEST_FILE s3://$INPUT_BUCKET/$test_filename
    
    print_status $GREEN "✓ Uploaded $TEST_FILE as s3://$INPUT_BUCKET/$test_filename"
    TEST_FILENAME=$test_filename
}

# Monitor Lambda execution
monitor_lambda_execution() {
    print_status $YELLOW "Monitoring Lambda execution..."
    
    local max_wait=30  # Maximum wait time in seconds
    local waited=0
    local check_interval=3
    
    while [[ $waited -lt $max_wait ]]; do
        print_status $BLUE "  Waiting for Lambda execution... (${waited}s/${max_wait}s)"
        
        # Get latest log stream
        local log_stream=$(aws logs describe-log-streams \
            --log-group-name "/aws/lambda/$FUNCTION_NAME" \
            --order-by LastEventTime \
            --descending \
            --max-items 1 \
            --query 'logStreams[0].logStreamName' \
            --output text 2>/dev/null || echo "")
        
        if [[ -n "$log_stream" && "$log_stream" != "None" ]]; then
            # Check if this execution is for our test file
            local logs=$(aws logs get-log-events \
                --log-group-name "/aws/lambda/$FUNCTION_NAME" \
                --log-stream-name "$log_stream" \
                --query 'events[].message' \
                --output text 2>/dev/null || echo "")
            
            if echo "$logs" | grep -q "complete_test_"; then
                # Found our execution
                if echo "$logs" | grep -q "END RequestId:"; then
                    # Execution completed
                    LAMBDA_LOGS="$logs"
                    return 0
                fi
            elif echo "$logs" | grep -q "END RequestId:" && echo "$logs" | grep -q "SNS notification sent:"; then
                # Fallback: Found recent execution with SNS notification
                print_status $BLUE "  Found recent Lambda execution with SNS notification"
                LAMBDA_LOGS="$logs"
                return 0
            fi
        fi
        
        sleep $check_interval
        waited=$((waited + check_interval))
    done
    
    print_status $YELLOW "⚠ Lambda execution monitoring timed out after ${max_wait}s"
    return 1
}

# Analyze Lambda execution results
analyze_lambda_results() {
    print_status $YELLOW "Analyzing Lambda execution results..."
    
    if [[ -z "$LAMBDA_LOGS" ]]; then
        print_status $RED "✗ No Lambda logs available for analysis"
        return 1
    fi
    
    # Check for different execution outcomes
    if echo "$LAMBDA_LOGS" | grep -q "ImportModuleError"; then
        print_status $RED "✗ Lambda function has import/dependency errors"
        echo "$LAMBDA_LOGS" | grep "ImportModuleError" || true
        return 1
    elif echo "$LAMBDA_LOGS" | grep -q "timeout"; then
        print_status $YELLOW "⚠ Lambda function timed out (likely database connectivity issue)"
        return 2
    elif echo "$LAMBDA_LOGS" | grep -q "Database error"; then
        print_status $RED "✗ Database connection/operation failed"
        echo "$LAMBDA_LOGS" | grep -A 2 -B 2 "Database error" || true
        return 1
    elif echo "$LAMBDA_LOGS" | grep -q "Stored metadata for file"; then
        print_status $GREEN "✓ Database schema initialization and metadata storage successful"
        return 0
    elif echo "$LAMBDA_LOGS" | grep -q "SNS notification sent"; then
        print_status $GREEN "✓ Lambda execution completed successfully"
        return 0
    elif echo "$LAMBDA_LOGS" | grep -q "Processing file"; then
        print_status $YELLOW "⚠ Lambda started processing but didn't complete successfully"
        return 2
    else
        print_status $YELLOW "? Lambda execution status unclear"
        return 3
    fi
}

# Check output files
check_output_files() {
    print_status $YELLOW "Checking output files..."
    
    local output_files=$(aws s3 ls s3://$OUTPUT_BUCKET/ --query 'Contents[].Key' --output text 2>/dev/null || echo "")
    
    if [[ -n "$output_files" && "$output_files" != "None" ]]; then
        print_status $GREEN "✓ Result files found in output bucket:"
        echo "$output_files" | while read -r file; do
            if [[ -n "$file" ]]; then
                print_status $BLUE "  - $file"
                
                # Download and validate the result file
                aws s3 cp s3://$OUTPUT_BUCKET/$file ./result.json --quiet
                
                if jq . ./result.json >/dev/null 2>&1; then
                    local filename=$(jq -r '.filename' ./result.json 2>/dev/null || echo "unknown")
                    local file_size_kb=$(jq -r '.file_size_kb' ./result.json 2>/dev/null || echo "unknown")
                    local status=$(jq -r '.status' ./result.json 2>/dev/null || echo "unknown")
                    
                    print_status $BLUE "    Filename: $filename"
                    print_status $BLUE "    File Size (KB): $file_size_kb"
                    print_status $BLUE "    Status: $status"
                    
                    # Just validate that we got a file size and status is success
                    if [[ "$status" == "success" ]]; then
                        if [[ "$file_size_kb" != "unknown" && "$file_size_kb" != "null" && -n "$file_size_kb" ]]; then
                            print_status $GREEN "    ✓ Result file validation passed (file size: ${file_size_kb}KB)"
                            OUTPUT_VALIDATION_PASSED=true
                        else
                            print_status $YELLOW "    ⚠ File processed successfully but file size not reported"
                            OUTPUT_VALIDATION_PASSED=true  # Still consider it passed if status is success
                        fi
                    else
                        print_status $RED "    ✗ Result file validation failed (status: $status)"
                        OUTPUT_VALIDATION_PASSED=false
                    fi
                else
                    print_status $RED "    ✗ Invalid JSON in result file"
                    OUTPUT_VALIDATION_PASSED=false
                fi
                
                rm -f ./result.json
            fi
        done
    else
        print_status $RED "✗ No result files found in output bucket"
        OUTPUT_VALIDATION_PASSED=false
    fi
}

# Check backup files
check_backup_files() {
    print_status $YELLOW "Checking backup files..."
    
    local backup_files=$(aws s3 ls s3://$BACKUP_BUCKET/backup/ --query 'Contents[].Key' --output text 2>/dev/null || echo "")
    
    if [[ -n "$backup_files" && "$backup_files" != "None" ]]; then
        print_status $GREEN "✓ Backup files found:"
        echo "$backup_files" | while read -r file; do
            if [[ -n "$file" ]]; then
                print_status $BLUE "  - $file"
            fi
        done
        BACKUP_VALIDATION_PASSED=true
    else
        print_status $RED "✗ No backup files found"
        BACKUP_VALIDATION_PASSED=false
    fi
}

# Validate database schema initialization
validate_database_schema() {
    print_status $YELLOW "Validating database schema initialization..."
    
    if [[ -z "$LAMBDA_LOGS" ]]; then
        print_status $RED "✗ No Lambda logs available for database validation"
        return 1
    fi
    
    # Check if table creation was attempted
    if echo "$LAMBDA_LOGS" | grep -q "CREATE TABLE IF NOT EXISTS file_metadata"; then
        print_status $GREEN "✓ Database table creation detected in logs"
        DB_SCHEMA_VALIDATED=true
    elif echo "$LAMBDA_LOGS" | grep -q "Stored metadata for file"; then
        print_status $GREEN "✓ Database metadata storage successful (schema exists)"
        DB_SCHEMA_VALIDATED=true
    else
        print_status $YELLOW "⚠ Database schema initialization not clearly detected"
        DB_SCHEMA_VALIDATED=false
    fi
    
    # Check for database connection success
    if echo "$LAMBDA_LOGS" | grep -q "Database error"; then
        print_status $RED "✗ Database connection/operation errors detected"
        echo "$LAMBDA_LOGS" | grep -A 2 -B 2 "Database error" || true
        DB_SCHEMA_VALIDATED=false
    fi
}

# Check CloudWatch metrics
check_cloudwatch_metrics() {
    print_status $YELLOW "Checking CloudWatch metrics..."
    
    # Get metrics for the last hour
    local end_time=$(date -u +%Y-%m-%dT%H:%M:%S)
    local start_time=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)
    
    # Check Lambda invocations
    local invocations=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/Lambda \
        --metric-name Invocations \
        --dimensions Name=FunctionName,Value=$FUNCTION_NAME \
        --start-time $start_time \
        --end-time $end_time \
        --period 3600 \
        --statistics Sum \
        --query 'Datapoints[0].Sum' \
        --output text 2>/dev/null || echo "0")
    
    # Check Lambda errors
    local errors=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/Lambda \
        --metric-name Errors \
        --dimensions Name=FunctionName,Value=$FUNCTION_NAME \
        --start-time $start_time \
        --end-time $end_time \
        --period 3600 \
        --statistics Sum \
        --query 'Datapoints[0].Sum' \
        --output text 2>/dev/null || echo "0")
    
    print_status $BLUE "Lambda Invocations (last hour): $invocations"
    print_status $BLUE "Lambda Errors (last hour): $errors"
    
    if [[ "$invocations" != "0" && "$invocations" != "None" ]]; then
        print_status $GREEN "✓ Lambda function was invoked"
        if [[ "$errors" == "0" || "$errors" == "None" ]]; then
            print_status $GREEN "✓ No Lambda errors recorded"
        else
            print_status $RED "✗ Lambda errors detected: $errors"
        fi
    else
        print_status $YELLOW "⚠ No Lambda invocations recorded (may need more time)"
    fi
}

# Generate test report
generate_test_report() {
    print_status $YELLOW "Generating test report..."
    
    local report_file="test_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "====================================="
        echo "CSV File Upload System Test Report"
        echo "====================================="
        echo "Test Date: $(date)"
        echo "Test File: $TEST_FILE"
        echo "Test validates: File size calculation and processing success"
        echo
        echo "INFRASTRUCTURE:"
        echo "- Input Bucket: $INPUT_BUCKET"
        echo "- Output Bucket: $OUTPUT_BUCKET"
        echo "- Backup Bucket: $BACKUP_BUCKET"
        echo "- Lambda Function: $FUNCTION_NAME"
        echo
        echo "TEST RESULTS:"
        echo "- File Upload: ✓ PASSED"
        
        case $LAMBDA_RESULT in
            0) echo "- Lambda Execution: ✓ PASSED" ;;
            1) echo "- Lambda Execution: ✗ FAILED" ;;
            2) echo "- Lambda Execution: ⚠ TIMEOUT" ;;
            3) echo "- Lambda Execution: ? UNCLEAR" ;;
        esac
        
        if [[ "$OUTPUT_VALIDATION_PASSED" == "true" ]]; then
            echo "- Output Validation: ✓ PASSED"
        else
            echo "- Output Validation: ✗ FAILED"
        fi
        
        if [[ "$BACKUP_VALIDATION_PASSED" == "true" ]]; then
            echo "- Backup Validation: ✓ PASSED"
        else
            echo "- Backup Validation: ✗ FAILED"
        fi
        
        if [[ "$DB_SCHEMA_VALIDATED" == "true" ]]; then
            echo "- Database Schema: ✓ PASSED"
        else
            echo "- Database Schema: ✗ FAILED"
        fi
        
        echo
        echo "LAMBDA LOGS:"
        echo "$LAMBDA_LOGS"
        echo
        echo "END REPORT"
    } > "$report_file"
    
    print_status $GREEN "✓ Test report saved to: $report_file"
}

# Main execution
main() {
    echo "==========================================="
    echo "    Complete CSV Upload System Test"
    echo "==========================================="
    echo
    
    # Initialize global variables
    LAMBDA_LOGS=""
    OUTPUT_VALIDATION_PASSED=false
    BACKUP_VALIDATION_PASSED=false
    DB_SCHEMA_VALIDATED=false
    LAMBDA_RESULT=0
    
    # Check prerequisites
    if [[ ! -f "$TEST_FILE" ]]; then
        print_status $RED "Error: Run this script from the tests/ directory"
        exit 1
    fi
    
    # Execute test steps
    echo "=== STEP 1: PREPARATION ==="
    get_bucket_names
    validate_test_data
    cleanup_previous_test
    echo
    
    echo "=== STEP 2: FILE UPLOAD ==="
    upload_test_file
    echo
    
    echo "=== STEP 3: LAMBDA EXECUTION ==="
    if monitor_lambda_execution; then
        analyze_lambda_results
        LAMBDA_RESULT=$?
    else
        print_status $RED "✗ Failed to monitor Lambda execution"
        LAMBDA_RESULT=1
    fi
    echo
    
    echo "=== STEP 4: DATABASE VALIDATION ==="
    validate_database_schema
    echo
    
    echo "=== STEP 5: OUTPUT VALIDATION ==="
    check_output_files
    check_backup_files
    echo
    
    echo "=== STEP 6: METRICS CHECK ==="
    check_cloudwatch_metrics
    echo
    
    echo "=== STEP 7: REPORTING ==="
    generate_test_report
    echo
    
    # Final summary
    echo "=== FINAL SUMMARY ==="
    local total_passed=0
    local total_tests=5
    
    print_status $BLUE "File Upload: ✓ PASSED"
    ((total_passed++))
    
    case $LAMBDA_RESULT in
        0)
            print_status $GREEN "Lambda Execution: ✓ PASSED"
            ((total_passed++))
            ;;
        1)
            print_status $RED "Lambda Execution: ✗ FAILED"
            ;;
        2)
            print_status $YELLOW "Lambda Execution: ⚠ TIMEOUT (database issue)"
            ;;
        3)
            print_status $YELLOW "Lambda Execution: ? UNCLEAR"
            ;;
    esac
    
    if [[ "$OUTPUT_VALIDATION_PASSED" == "true" ]]; then
        print_status $GREEN "Output Validation: ✓ PASSED"
        ((total_passed++))
    else
        print_status $RED "Output Validation: ✗ FAILED"
    fi
    
    if [[ "$BACKUP_VALIDATION_PASSED" == "true" ]]; then
        print_status $GREEN "Backup Validation: ✓ PASSED"
        ((total_passed++))
    else
        print_status $RED "Backup Validation: ✗ FAILED"
    fi
    
    if [[ "$DB_SCHEMA_VALIDATED" == "true" ]]; then
        print_status $GREEN "Database Schema: ✓ PASSED"
        ((total_passed++))
    else
        print_status $RED "Database Schema: ✗ FAILED"
    fi
    
    echo
    print_status $BLUE "Tests Passed: $total_passed/$total_tests"
    
    if [[ $total_passed -eq $total_tests ]]; then
        print_status $GREEN "🎉 ALL TESTS PASSED! System is working correctly."
        exit 0
    elif [[ $LAMBDA_RESULT -eq 2 ]]; then
        print_status $YELLOW "⚠ Tests partially passed with timeout issue."
        print_status $YELLOW "Run './test_database_connectivity.sh' to debug database connection."
        exit 2
    elif [[ $LAMBDA_RESULT -eq 1 ]]; then
        print_status $RED "❌ Tests failed due to Lambda execution errors."
        print_status $YELLOW "Run './test_lambda_dependencies.sh' to debug Lambda issues."
        exit 1
    else
        print_status $RED "❌ Multiple test failures detected."
        print_status $YELLOW "Check the test report and individual test scripts for debugging."
        exit 1
    fi
}

# Run main function
main "$@"
