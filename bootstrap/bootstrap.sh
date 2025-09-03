#!/bin/bash
set -e

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)
REPO="smartech-devops/file_upload"
RANDOM_SUFFIX=$(openssl rand -hex 4)
BUCKET_NAME="file-upload-terraform-state-${RANDOM_SUFFIX}"

echo "Using region: ${REGION}"
echo "Creating S3 bucket for Terraform state..."

# Create S3 bucket
aws s3 mb s3://${BUCKET_NAME} --region ${REGION}

echo "Creating GitHub OIDC provider..."

# Create OIDC provider (ignore if already exists)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  2>/dev/null || echo "OIDC provider already exists, skipping..."

echo "Creating trust policy..."

# Trust policy
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:${REPO}:ref:refs/heads/master"
        }
      }
    }
  ]
}
EOF

echo "Creating GitHub Actions role..."

# Create role (ignore if already exists)
aws iam create-role \
  --role-name github-actions-deploy-role \
  --assume-role-policy-document file://trust-policy.json \
  2>/dev/null || echo "Role already exists, skipping..."

# Attach admin policy (ignore if already attached)
aws iam attach-role-policy \
  --role-name github-actions-deploy-role \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  2>/dev/null || echo "Policy already attached, skipping..."

# Get role ARN
ROLE_ARN=$(aws iam get-role --role-name github-actions-deploy-role --query 'Role.Arn' --output text)

echo "Bootstrap complete!"
echo "S3 Bucket: ${BUCKET_NAME}"
echo "Role ARN: ${ROLE_ARN}"
echo ""
echo "Add this to GitHub repository secrets:"
echo "AWS_ROLE_ARN=${ROLE_ARN}"
echo ""
echo "Add this to terraform/backend.tf:"
echo "bucket = \"${BUCKET_NAME}\""
echo "region = \"${REGION}\""

# Cleanup
rm trust-policy.json