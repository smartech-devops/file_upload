# AWS Data Processing Pipeline

A serverless CSV file processing system built with AWS Lambda, S3, RDS, and SNS.

📋 **Detailed PRDs and documentation can be found in the `design/` folder.**

## Architecture

- **S3 Buckets**: Input, output, and backup storage
- **Lambda Function**: CSV processor with automatic triggers
- **RDS PostgreSQL**: File metadata storage
- **SNS**: Email notifications
- **CloudWatch**: Monitoring and alerting
- **GitHub Actions**: CI/CD pipeline

## Setup

### 1. Bootstrap (One-time setup)

Run the bootstrap script from your laptop:

```bash
cd bootstrap/
chmod +x bootstrap.sh
./bootstrap.sh
```

This creates:
- S3 bucket for Terraform state
- GitHub OIDC provider
- GitHub Actions IAM role

### 2. Configure GitHub

Add the following secrets to your GitHub repository:
- `AWS_ROLE_ARN`: Role ARN from bootstrap output

### 3. Update Backend Configuration

Update `terraform/backend.tf` with the bucket name from bootstrap output.

### 4. Deploy

Push to master branch to trigger automated deployment via GitHub Actions.

## Usage

1. Upload CSV files to the input S3 bucket
2. Lambda processes files automatically
3. Results stored in output bucket
4. Files backed up to backup bucket
5. Metadata stored in RDS
6. Email notifications sent via SNS

## Testing

Run the complete test script:

```bash
./scripts/run-complete-test.sh
```

## Development

- **Lambda Code**: `lambda/lambda_function.py`
- **Dependencies**: `lambda/requirements.txt`
- **Infrastructure**: `terraform/` directory
- **CI/CD**: `.github/workflows/deploy.yml`