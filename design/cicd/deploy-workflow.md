# Deploy Workflow Design

## Workflow Overview

**Name**: Deploy Lambda Function  
**Trigger**: Push to main branch  
**Runner**: ubuntu-latest  
**Purpose**: Package Lambda code, deploy infrastructure, and update function

## Workflow Steps

### 1. Code Checkout
- **Action**: Check out repository code
- **Purpose**: Access Lambda source code and Terraform files
- **Inputs**: Current commit from main branch

### 2. AWS Authentication
- **Action**: Configure AWS credentials via OIDC assume role
- **Purpose**: Authenticate with AWS for deployment operations
- **Method**: GitHub OIDC provider assumes IAM role
- **Secrets Required**:
  - `AWS_ROLE_ARN` (IAM role to assume)
- **Region**: us-east-1
- **Benefits**: No long-lived credentials, automatic token rotation

### 3. Python Environment Setup
- **Action**: Set up Python runtime
- **Version**: 3.9 (Lambda compatible)
- **Purpose**: Install dependencies and package Lambda code

### 4. Dependency Installation
- **Action**: Install Python packages
- **Target**: lambda/ directory
- **Command**: pip install -r requirements.txt -t .
- **Purpose**: Bundle dependencies with Lambda code

### 5. Package Creation
- **Action**: Create deployment ZIP archive
- **Source**: lambda/ directory contents
- **Output**: lambda-deployment.zip
- **Purpose**: Prepare Lambda deployment package

### 6. Infrastructure Deployment (Terraform)
- **Action**: Run terraform plan and apply
- **Target**: terraform/ directory
- **Purpose**: Create/update AWS infrastructure
- **Resources Managed**:
  - S3 buckets (input, output, backup)
  - Lambda function
  - RDS instance
  - SNS topic
  - CloudWatch alarms
  - IAM roles and policies

### 7. Lambda Function Update
- **Action**: Update Lambda function code
- **Method**: AWS CLI update-function-code
- **Package**: lambda-deployment.zip
- **Purpose**: Deploy new Lambda code to existing function

### 8. Deployment Verification
- **Action**: Wait for function update completion
- **Method**: AWS CLI wait function-updated
- **Purpose**: Ensure deployment is fully complete

### 9. Function Testing
- **Action**: Invoke Lambda function with test payload
- **Purpose**: Verify deployment success and function health
- **Output**: Log response for debugging

## Workflow Variables

- **AWS_REGION**: us-east-1
- **LAMBDA_FUNCTION_NAME**: csv-processor
- **TERRAFORM_VERSION**: latest

## Security Considerations

- **OIDC assume role** instead of long-lived credentials
- **No AWS credentials** stored as GitHub secrets
- **GitHub OIDC provider** trusted by AWS IAM role
- **Temporary tokens** automatically rotated
- **Terraform state** managed securely (S3 backend with state locking)
- **IAM permissions** follow least privilege principle
- **Role-based access** with specific deployment permissions only

## Rollback Strategy

- Keep previous Lambda version for quick rollback
- Terraform state backup before changes
- Manual rollback via AWS CLI if needed