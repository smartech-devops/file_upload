# Run CSV Processor Tests Action

A composite GitHub Action that runs post-deployment validation tests for the CSV processor infrastructure.

## Description

This action executes the comprehensive test suite to validate that the deployed CSV processor infrastructure is working correctly. It runs infrastructure, integration, and functional tests to ensure the system is healthy after deployment.

## Usage

### Basic Usage

```yaml
- name: Run Post-Deployment Tests
  uses: ./.github/actions/run-tests
```

### With Custom Parameters

```yaml
- name: Run Integration Tests Only
  uses: ./.github/actions/run-tests
  with:
    test-phase: 'integration'
    aws-region: 'eu-north-1'
    verbose: 'true'
```

### With Output Handling

```yaml
- name: Run Tests and Handle Results
  id: test-run
  uses: ./.github/actions/run-tests
  with:
    test-phase: 'all'

- name: Check Test Results
  run: |
    echo "Tests passed: ${{ steps.test-run.outputs.tests-passed }}"
    echo "Tests failed: ${{ steps.test-run.outputs.tests-failed }}"
    echo "Results: ${{ steps.test-run.outputs.test-results }}"
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `test-phase` | Test phase to run (`infrastructure`, `integration`, `functional`, `all`) | No | `all` |
| `aws-region` | AWS region where infrastructure is deployed | No | `eu-north-1` |
| `verbose` | Enable verbose test output | No | `false` |

## Outputs

| Output | Description |
|--------|-------------|
| `test-results` | Test execution summary (e.g., "Total: 10, Passed: 8, Failed: 2") |
| `log-file` | Path to the test results log file |
| `tests-passed` | Number of tests that passed |
| `tests-failed` | Number of tests that failed |

## Test Phases

### Infrastructure Tests
- **Network Connectivity**: Validates VPC peering and security groups
- **Resource Deployment**: Verifies all AWS resources are deployed correctly
- **Permissions**: Validates IAM roles and policies

### Integration Tests
- **S3 Lambda Trigger**: Tests S3 to Lambda event triggering
- **Lambda RDS Connection**: Validates Lambda can connect to RDS
- **End-to-End Workflow**: Tests complete CSV processing workflow
- **Error Handling**: Validates error scenarios and notifications

### Functional Tests
- **CSV Processing**: Tests various CSV file formats and processing
- **Data Validation**: Tests data validation rules and constraints

## Prerequisites

This action requires:

1. **AWS Credentials**: Must be configured before calling this action
2. **Terraform State**: Infrastructure must be deployed via Terraform
3. **Test Suite**: The `./tests/` directory must exist with test scripts
4. **Permissions**: AWS credentials must have access to deployed resources

## Artifacts

The action automatically uploads test results as GitHub Actions artifacts:

- **Name**: `test-results-{run-id}`
- **Contents**: All test log files
- **Retention**: 30 days

## Example Workflow Integration

```yaml
name: Deploy and Test Infrastructure

on:
  push:
    branches: [ master ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: eu-north-1
      
      # ... deployment steps ...
      
      - name: Run Post-Deployment Tests
        uses: ./.github/actions/run-tests
        with:
          test-phase: 'all'
          verbose: 'true'
```

## Error Handling

- **Action fails** if any test fails (exit code != 0)
- **Logs uploaded** even on failure for debugging
- **Detailed output** shows which specific tests failed
- **Prerequisites checked** before running tests

## Development

### Testing the Action Locally

You can test the underlying test runner directly:

```bash
# Run all tests
./tests/run-tests.sh --phase all --verbose

# Run specific phase
./tests/run-tests.sh --phase integration
```

### Adding New Tests

1. Add test scripts to the appropriate directory:
   - `tests/infrastructure/` for infrastructure tests
   - `tests/integration/` for integration tests  
   - `tests/functional/` for functional tests

2. Update the test runner (`tests/run-tests.sh`) if needed

3. Test scripts should follow the naming pattern: `test-*.sh`

## Troubleshooting

### Common Issues

1. **"AWS credentials not configured"**
   - Ensure AWS credentials are set up before calling this action

2. **"Terraform directory not found"**
   - Make sure the workflow runs from the repository root
   - Verify `./terraform/` directory exists

3. **"Test runner not executable"**
   - Ensure test scripts have execute permissions
   - Run: `chmod +x tests/run-tests.sh`

4. **Tests timeout or fail**
   - Check the uploaded test logs in GitHub Actions artifacts
   - Verify all infrastructure is properly deployed
   - Check AWS CloudWatch logs for Lambda/RDS issues

### Debug Mode

Enable verbose mode for detailed output:

```yaml
- uses: ./.github/actions/run-tests
  with:
    verbose: 'true'
```

## Contributing

When modifying this action:

1. Update the `action.yml` file for new inputs/outputs
2. Update this README with new documentation
3. Test the action in a feature branch before merging
4. Follow semantic versioning for any breaking changes