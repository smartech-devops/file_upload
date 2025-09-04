#!/bin/bash

# CSV Processor Test Suite
# Main test runner for post-deployment validation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$TEST_DIR")"
TERRAFORM_DIR="$ROOT_DIR/terraform"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$TEST_DIR/test-results-$TIMESTAMP.log"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Utility functions
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[PASS]${NC} $1"
    ((PASSED_TESTS++))
}

log_error() {
    log "${RED}[FAIL]${NC} $1"
    ((FAILED_TESTS++))
}

log_warning() {
    log "${YELLOW}[WARN]${NC} $1"
}

run_test() {
    local test_name="$1"
    local test_script="$2"
    
    ((TOTAL_TESTS++))
    log_info "Running test: $test_name"
    
    if bash "$test_script" >> "$LOG_FILE" 2>&1; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        return 1
    fi
}

# Parse command line arguments
PHASE="all"
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --phase)
            PHASE="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --phase PHASE    Run specific test phase (infrastructure|integration|functional|all)"
            echo "  --verbose, -v    Enable verbose output"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Verify prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check if Terraform outputs are available
    if [ ! -d "$TERRAFORM_DIR" ]; then
        log_error "Terraform directory not found: $TERRAFORM_DIR"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    log_success "Prerequisites check completed"
}

# Get Terraform outputs
get_terraform_outputs() {
    log_info "Retrieving Terraform outputs..."
    
    cd "$TERRAFORM_DIR"
    
    # Export Terraform outputs as environment variables
    export INPUT_BUCKET_NAME=$(terraform output -raw input_bucket_name 2>/dev/null || echo "")
    export OUTPUT_BUCKET_NAME=$(terraform output -raw output_bucket_name 2>/dev/null || echo "")
    export BACKUP_BUCKET_NAME=$(terraform output -raw backup_bucket_name 2>/dev/null || echo "")
    export LAMBDA_FUNCTION_NAME=$(terraform output -raw lambda_function_name 2>/dev/null || echo "")
    export DB_SECRET_NAME=$(terraform output -raw db_secret_name 2>/dev/null || echo "")
    export SNS_TOPIC_ARN=$(terraform output -raw sns_topic_arn 2>/dev/null || echo "")
    export AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "eu-north-1")
    
    cd "$TEST_DIR"
    
    # Validate critical outputs
    if [ -z "$INPUT_BUCKET_NAME" ] || [ -z "$LAMBDA_FUNCTION_NAME" ]; then
        log_error "Failed to retrieve required Terraform outputs"
        log_error "Make sure Terraform has been applied successfully"
        exit 1
    fi
    
    log_success "Terraform outputs retrieved successfully"
}

# Run infrastructure tests
run_infrastructure_tests() {
    log_info "=== INFRASTRUCTURE TESTS ==="
    
    run_test "Network Connectivity" "$TEST_DIR/infrastructure/test-network-connectivity.sh"
    run_test "Resource Deployment" "$TEST_DIR/infrastructure/test-resource-deployment.sh"
    run_test "Permissions Validation" "$TEST_DIR/infrastructure/test-permissions.sh"
}

# Run integration tests
run_integration_tests() {
    log_info "=== INTEGRATION TESTS ==="
    
    run_test "S3 Lambda Trigger" "$TEST_DIR/integration/test-s3-lambda-trigger.sh"
    run_test "Lambda RDS Connection" "$TEST_DIR/integration/test-lambda-rds-connection.sh"
    run_test "End-to-End Workflow" "$TEST_DIR/integration/test-end-to-end-workflow.sh"
    run_test "Error Handling" "$TEST_DIR/integration/test-error-handling.sh"
}

# Run functional tests
run_functional_tests() {
    log_info "=== FUNCTIONAL TESTS ==="
    
    run_test "CSV Processing" "$TEST_DIR/functional/test-csv-processing.sh"
    run_test "Data Validation" "$TEST_DIR/functional/test-data-validation.sh"
}


# Generate test report
generate_report() {
    log_info "=== TEST SUMMARY ==="
    log_info "Total Tests: $TOTAL_TESTS"
    log_success "Passed: $PASSED_TESTS"
    log_error "Failed: $FAILED_TESTS"
    log_info "Test Log: $LOG_FILE"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log_success "All tests passed! ✅"
        return 0
    else
        log_error "Some tests failed! ❌"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting CSV Processor Test Suite - $(date)"
    log_info "Phase: $PHASE"
    log_info "Verbose: $VERBOSE"
    
    check_prerequisites
    get_terraform_outputs
    
    case $PHASE in
        infrastructure)
            run_infrastructure_tests
            ;;
        integration)
            run_integration_tests
            ;;
        functional)
            run_functional_tests
            ;;
        all)
            run_infrastructure_tests
            run_integration_tests
            run_functional_tests
            ;;
        *)
            log_error "Invalid phase: $PHASE"
            exit 1
            ;;
    esac
    
    generate_report
}

# Execute main function
main "$@"