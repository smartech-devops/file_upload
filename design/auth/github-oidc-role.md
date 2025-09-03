# GitHub OIDC IAM Role Design

## Overview

IAM role that GitHub Actions assumes via OIDC to deploy AWS resources without storing long-lived credentials.

## IAM Role Configuration

### Role Name
`github-actions-deploy-role`

### Trust Policy
- **Principal**: GitHub OIDC provider
- **Conditions**: 
  - Repository: `<your-org>/<your-repo>`
  - Branch: `main`
  - GitHub token audience: `sts.amazonaws.com`

### Required Permissions

#### Lambda Permissions
- `lambda:UpdateFunctionCode`
- `lambda:UpdateFunctionConfiguration` 
- `lambda:GetFunction`
- `lambda:InvokeFunction`
- `lambda:CreateFunction` (for initial deployment)
- `lambda:DeleteFunction`
- `lambda:TagResource`
- `lambda:UntagResource`

#### S3 Permissions
- `s3:CreateBucket`
- `s3:DeleteBucket`
- `s3:PutBucketNotification`
- `s3:GetBucketNotification`
- `s3:PutBucketVersioning`
- `s3:GetBucketVersioning`
- `s3:PutBucketPublicAccessBlock`
- `s3:GetBucketPublicAccessBlock`
- `s3:ListBucket`
- `s3:GetObject`
- `s3:PutObject`
- `s3:DeleteObject`

#### RDS Permissions
- `rds:CreateDBInstance`
- `rds:DeleteDBInstance`
- `rds:ModifyDBInstance`
- `rds:DescribeDBInstances`
- `rds:CreateDBSubnetGroup`
- `rds:DeleteDBSubnetGroup`
- `rds:DescribeDBSubnetGroups`
- `rds:AddTagsToResource`
- `rds:RemoveTagsFromResource`

#### Secrets Manager Permissions
- `secretsmanager:CreateSecret`
- `secretsmanager:UpdateSecret`
- `secretsmanager:DeleteSecret`
- `secretsmanager:DescribeSecret`
- `secretsmanager:GetSecretValue`
- `secretsmanager:PutSecretValue`
- `secretsmanager:TagResource`
- `secretsmanager:UntagResource`

#### SNS Permissions
- `sns:CreateTopic`
- `sns:DeleteTopic`
- `sns:Subscribe`
- `sns:Unsubscribe`
- `sns:Publish`
- `sns:GetTopicAttributes`
- `sns:SetTopicAttributes`
- `sns:ListSubscriptionsByTopic`
- `sns:TagResource`
- `sns:UntagResource`

#### CloudWatch Permissions
- `cloudwatch:PutMetricAlarm`
- `cloudwatch:DeleteAlarms`
- `cloudwatch:DescribeAlarms`
- `cloudwatch:EnableAlarmActions`
- `cloudwatch:DisableAlarmActions`
- `logs:CreateLogGroup`
- `logs:CreateLogStream`
- `logs:PutLogEvents`
- `logs:DescribeLogGroups`
- `logs:DescribeLogStreams`

#### IAM Permissions (for Terraform)
- `iam:CreateRole`
- `iam:DeleteRole`
- `iam:AttachRolePolicy`
- `iam:DetachRolePolicy`
- `iam:PutRolePolicy`
- `iam:DeleteRolePolicy`
- `iam:GetRole`
- `iam:ListRolePolicies`
- `iam:PassRole`
- `iam:TagRole`
- `iam:UntagRole`

#### EC2 Permissions (for VPC/Security Groups)
- `ec2:CreateVpc`
- `ec2:DeleteVpc`
- `ec2:CreateSubnet`
- `ec2:DeleteSubnet`
- `ec2:CreateSecurityGroup`
- `ec2:DeleteSecurityGroup`
- `ec2:AuthorizeSecurityGroupIngress`
- `ec2:RevokeSecurityGroupIngress`
- `ec2:DescribeVpcs`
- `ec2:DescribeSubnets`
- `ec2:DescribeSecurityGroups`
- `ec2:DescribeAvailabilityZones`
- `ec2:CreateTags`
- `ec2:DeleteTags`

## OIDC Provider Setup

### GitHub OIDC Provider
- **URL**: `https://token.actions.githubusercontent.com`
- **Thumbprint**: GitHub's certificate thumbprint
- **Audience**: `sts.amazonaws.com`

### Trust Relationship Conditions
- **Repository**: Must match exact repo path
- **Branch**: Only `main` branch allowed
- **Actor**: Optional - restrict to specific GitHub users

## Resource Restrictions

### S3 Bucket Naming
- Only allow buckets with prefix: `candidate-test-*`
- Prevent creation of other buckets

### RDS Instance Restrictions
- Only allow `db.t3.micro` instance types
- Restrict to specific VPC/subnets
- Enforce encryption at rest

### Lambda Function Restrictions
- Only allow functions with prefix: `csv-*`
- Restrict runtime to Python 3.9
- Limit memory and timeout

## Terraform State Management

### Backend Configuration
- **S3 Bucket**: For storing Terraform state
- **DynamoDB Table**: For state locking
- **Encryption**: State file encrypted at rest
- **Versioning**: Enable S3 versioning for state history

### Required Additional Permissions
- `s3:GetObject` on Terraform state bucket
- `s3:PutObject` on Terraform state bucket
- `dynamodb:GetItem` on state lock table
- `dynamodb:PutItem` on state lock table
- `dynamodb:DeleteItem` on state lock table