# Package Lambda Function Action

A composite GitHub Action that packages Lambda function code with dependencies into a deployment-ready zip file using standard pip (no uv dependency required).

## Description

This action creates AWS Lambda deployment packages by:
- Setting up the specified Python version
- Copying Lambda function code
- Installing dependencies using pip with `--target` flag
- Creating an optimized zip file
- Validating package size against Lambda limits
- Providing detailed package information

## Features

- **🚀 No External Dependencies**: Uses standard pip (no uv setup required)
- **📦 Smart Packaging**: Efficiently packages code and dependencies
- **🔍 Validation**: Checks Lambda size limits and common issues
- **📊 Rich Outputs**: Package size, dependency count, validation status
- **🛡️ Error Handling**: Comprehensive validation and error reporting
- **📋 Artifact Support**: Optional artifact upload
- **🧹 Clean**: Automatic cleanup of temporary files

## Usage

### Basic Usage

```yaml
- name: Package Lambda Function
  uses: ./.github/actions/package-lambda
```

### With Custom Configuration

```yaml
- name: Package Lambda Function
  uses: ./.github/actions/package-lambda
  with:
    lambda-directory: 'src/lambda'
    output-filename: 'my-lambda.zip'
    python-version: '3.11'
    show-contents: 'true'
    upload-artifact: 'true'
```

### With Output Handling

```yaml
- name: Package Lambda Function
  id: package
  uses: ./.github/actions/package-lambda

- name: Check Package Size
  run: |
    echo "Package size: ${{ steps.package.outputs.package-size-mb }} MB"
    echo "Within limits: ${{ steps.package.outputs.within-size-limit }}"
    if [ "${{ steps.package.outputs.within-size-limit }}" = "false" ]; then
      echo "Warning: Package may be too large for Lambda"
    fi
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `lambda-directory` | Directory containing Lambda function code | No | `lambda` |
| `output-filename` | Name of the output zip file | No | `lambda-deployment.zip` |
| `requirements-file` | Path to requirements.txt (relative to lambda-directory) | No | `requirements.txt` |
| `python-version` | Python version to use for packaging | No | `3.9` |
| `show-contents` | Display package contents in logs | No | `true` |
| `upload-artifact` | Upload package as GitHub Actions artifact | No | `false` |

## Outputs

| Output | Description |
|--------|-------------|
| `package-path` | Full path to the created deployment package |
| `package-size` | Size of the deployment package in bytes |
| `package-size-mb` | Size of the deployment package in MB |
| `dependencies-count` | Number of dependencies installed |
| `within-size-limit` | Whether package is within Lambda size limits (`true`/`false`) |

## Requirements File Format

Create a `requirements.txt` file in your Lambda directory:

```txt
boto3>=1.26.0
psycopg2-binary>=2.9.0
requests>=2.28.0
```

The action will automatically install these dependencies into the package.

## Lambda Size Limits

The action validates against AWS Lambda limits:

- **Zipped package**: 50 MB maximum
- **Unzipped package**: 250 MB maximum (estimated)

## Package Structure

The action creates packages with this structure:
```
lambda-deployment.zip
├── lambda_function.py          # Your Lambda code
├── other_module.py             # Additional Python files
├── boto3/                      # Dependencies
├── psycopg2/
└── ...                         # Other installed packages
```

## Validation Features

The action performs several validations:

### Size Validation
- Checks against Lambda zipped size limit (50 MB)
- Estimates unzipped size against limit (250 MB)
- Provides warnings for oversized packages

### Content Analysis
- Detects `__pycache__` directories (should be excluded)
- Identifies `.pyc` files (should be excluded)
- Lists Python files in the package
- Shows dependency count

## Error Handling

Common error scenarios handled:

### Missing Lambda Directory
```
❌ Lambda directory not found: lambda
```
**Solution**: Ensure the lambda directory exists or specify correct path

### No Python Files
```
❌ No Python files found in lambda
```
**Solution**: Add at least one .py file to the Lambda directory

### Dependency Installation Failure
```
❌ Failed to install dependencies
```
**Solution**: Check requirements.txt syntax and package availability

### Package Creation Failure
```
❌ Failed to create deployment package
```
**Solution**: Check file permissions and available disk space

## Workflow Integration Examples

### Basic Lambda Deployment

```yaml
name: Deploy Lambda Function
on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Package Lambda Function
        uses: ./.github/actions/package-lambda
        with:
          show-contents: 'true'
      
      - name: Deploy to AWS
        run: |
          # Use lambda-deployment.zip for deployment
          aws lambda update-function-code \
            --function-name my-function \
            --zip-file fileb://lambda-deployment.zip
```

### Multi-Environment Deployment

```yaml
name: Deploy Lambda to Environments
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        type: choice
        options:
        - dev
        - staging
        - prod

jobs:
  package:
    runs-on: ubuntu-latest
    outputs:
      package-path: ${{ steps.package.outputs.package-path }}
      package-size: ${{ steps.package.outputs.package-size-mb }}
    steps:
      - uses: actions/checkout@v4
      
      - name: Package Lambda Function
        id: package
        uses: ./.github/actions/package-lambda
        with:
          upload-artifact: 'true'

  deploy:
    needs: package
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment }}
    steps:
      - name: Download Package
        uses: actions/download-artifact@v4
        with:
          name: lambda-package-${{ github.run_id }}
      
      - name: Deploy Lambda
        run: |
          echo "Deploying package (${{ needs.package.outputs.package-size }} MB) to ${{ github.event.inputs.environment }}"
          # Deployment commands here
```

### Package Size Monitoring

```yaml
- name: Package Lambda Function
  id: package
  uses: ./.github/actions/package-lambda

- name: Check Package Size
  run: |
    SIZE_MB=${{ steps.package.outputs.package-size-mb }}
    if (( $(echo "$SIZE_MB > 40" | bc -l) )); then
      echo "::warning::Lambda package is getting large: ${SIZE_MB} MB"
    fi
    
    if [ "${{ steps.package.outputs.within-size-limit }}" = "false" ]; then
      echo "::error::Lambda package exceeds size limits"
      exit 1
    fi
```

## Comparison with uv

| Feature | This Action (pip) | uv |
|---------|------------------|-----|
| Setup required | ❌ No | ✅ Yes (`astral-sh/setup-uv@v3`) |
| Speed | Fast for simple deps | Faster for complex deps |
| Compatibility | Standard, widely supported | Modern, growing support |
| Lambda packaging | ✅ Perfect fit | ✅ Works but overkill |
| GitHub Actions integration | Native support | Requires additional step |

For simple Lambda functions with few dependencies (like boto3, psycopg2), standard pip is simpler and eliminates an extra workflow step.

## Troubleshooting

### Large Package Size

If your package is too large:

1. **Remove unnecessary files** from lambda directory
2. **Use lighter dependencies** where possible
3. **Consider Lambda layers** for large dependencies
4. **Exclude development dependencies**

### Missing Dependencies

If dependencies aren't working:

1. **Check requirements.txt syntax**
2. **Verify package names** on PyPI
3. **Use compatible versions** for Lambda Python runtime
4. **Consider platform-specific wheels** for binary packages

### Permission Errors

If packaging fails with permissions:

1. **Check file permissions** in lambda directory
2. **Ensure write access** to working directory
3. **Verify Python installation** and pip access

## Contributing

When modifying this action:

1. Test with different Python versions
2. Validate with various dependency combinations
3. Check size limit calculations accuracy
4. Verify cleanup procedures work properly
5. Update documentation for any new features