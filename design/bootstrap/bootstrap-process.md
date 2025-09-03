# Bootstrap Process Design

## Overview
Simple one-time setup to create the GitHub Actions OIDC role for automated deployments.

## Simplified Approach

### Local State (Keep It Simple)
- **Approach**: Use local Terraform state for bootstrap
- **Benefits**: No additional AWS resources, simple setup
- **Perfect for**: Job interview projects and single-developer work

## Bootstrap Process

### Step 1: Manual Bootstrap (Run Once)
1. Run `terraform init` in `bootstrap/` directory 
2. Run `terraform apply` with your personal AWS credentials
3. Creates:
   - GitHub OIDC identity provider
   - GitHub Actions deployment role with admin permissions
4. Outputs the role ARN for GitHub Actions

### Step 2: Configure GitHub Repository
1. Copy role ARN from terraform output
2. Add `AWS_ROLE_ARN` secret in GitHub repository settings
3. Push code to trigger automated deployment

**Result**: Simple, clean, and shows good engineering judgment for the scope of work.

## Bootstrap Resources Created

### OIDC Identity Provider
- **Provider URL**: `https://token.actions.githubusercontent.com`
- **Audience**: `sts.amazonaws.com`
- **Thumbprint**: GitHub's certificate thumbprint

### GitHub Actions IAM Role
- **Role Name**: `github-actions-deploy-role`
- **Trust Policy**: Only allows `smartech-devops/file_upload` repo on `main` branch
- **Permissions**: Full deployment permissions for all AWS services needed

## Security Configuration

### Trust Policy Restrictions
- **Repository**: `smartech-devops/file_upload` only
- **Branch**: `main` branch only
- **Audience**: `sts.amazonaws.com` only

### Permission Boundaries
- Scoped to specific resource prefixes (e.g., `candidate-test-*` for S3 buckets)
- Limited to required AWS services only
- No broad administrative permissions

## S3 Backend Configuration

### State Bucket Settings
- **Bucket Name**: `file-upload-terraform-state-<random-id>`
- **Encryption**: AES-256 server-side encryption
- **Versioning**: Enabled for state history
- **Public Access**: Blocked

### DynamoDB Lock Table
- **Table Name**: `terraform-state-lock`
- **Partition Key**: `LockID` (String)
- **Billing Mode**: On-demand (cost-effective for low usage)

## Troubleshooting

### Common Issues
1. **OIDC Provider Already Exists**: Delete existing provider or import into Terraform
2. **Role Name Conflicts**: Use unique role name or import existing role
3. **Permission Denied**: Ensure your AWS credentials have IAM admin permissions
4. **S3 Bucket Name Conflicts**: Bucket names must be globally unique
5. **State Migration Issues**: Ensure proper backend configuration before migration