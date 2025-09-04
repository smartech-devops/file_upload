#!/bin/bash

# Test: Permissions Validation
# Validates that all IAM roles and policies are properly configured

set -e

echo "Testing permissions configuration..."

# Test Lambda execution role
echo "Checking Lambda execution role..."
LAMBDA_ROLE_ARN=$(aws lambda get-function \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --query 'Configuration.Role' \
    --output text --region "$AWS_REGION")

if [ -z "$LAMBDA_ROLE_ARN" ]; then
    echo "ERROR: Lambda execution role not found"
    exit 1
fi

LAMBDA_ROLE_NAME=$(echo "$LAMBDA_ROLE_ARN" | cut -d'/' -f2)
echo "✓ Lambda execution role found: $LAMBDA_ROLE_NAME"

# Test Lambda role policies
echo "Checking Lambda role policies..."

# Check if Lambda has basic execution policy
BASIC_POLICY=$(aws iam list-attached-role-policies \
    --role-name "$LAMBDA_ROLE_NAME" \
    --query 'AttachedPolicies[?contains(PolicyName,`AWSLambdaVPCAccessExecutionRole`)].PolicyName' \
    --output text 2>/dev/null || echo "")

if [ -z "$BASIC_POLICY" ]; then
    echo "WARNING: AWSLambdaVPCAccessExecutionRole policy not found - checking inline policies"
fi

# Check inline policies for Lambda role
INLINE_POLICIES=$(aws iam list-role-policies \
    --role-name "$LAMBDA_ROLE_NAME" \
    --query 'PolicyNames' \
    --output text)

if [ -z "$INLINE_POLICIES" ] && [ -z "$BASIC_POLICY" ]; then
    echo "ERROR: No policies found for Lambda role"
    exit 1
fi

echo "✓ Lambda role has policies configured"

# Test Lambda's S3 permissions by checking policy documents
echo "Checking S3 permissions..."

# Get inline policy document if exists
for policy_name in $INLINE_POLICIES; do
    POLICY_DOC=$(aws iam get-role-policy \
        --role-name "$LAMBDA_ROLE_NAME" \
        --policy-name "$policy_name" \
        --query 'PolicyDocument' \
        --output text 2>/dev/null || echo "")
    
    if echo "$POLICY_DOC" | grep -q "s3:GetObject\|s3:PutObject\|s3:\*"; then
        echo "✓ Lambda has S3 permissions in policy: $policy_name"
        S3_PERMISSION_FOUND=true
        break
    fi
done

# Test Lambda permission for S3 to invoke it
echo "Checking S3 invoke permission for Lambda..."
INVOKE_PERMISSION=$(aws lambda get-policy \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --query 'Policy' \
    --output text --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -z "$INVOKE_PERMISSION" ]; then
    echo "ERROR: No resource policy found for Lambda function"
    exit 1
fi

if echo "$INVOKE_PERMISSION" | grep -q "s3.amazonaws.com"; then
    echo "✓ S3 has permission to invoke Lambda"
else
    echo "ERROR: S3 does not have permission to invoke Lambda"
    exit 1
fi

# Test Secrets Manager permissions
echo "Checking Secrets Manager permissions..."
SECRET_PERMISSION_FOUND=false

for policy_name in $INLINE_POLICIES; do
    POLICY_DOC=$(aws iam get-role-policy \
        --role-name "$LAMBDA_ROLE_NAME" \
        --policy-name "$policy_name" \
        --query 'PolicyDocument' \
        --output text 2>/dev/null || echo "")
    
    if echo "$POLICY_DOC" | grep -q "secretsmanager:GetSecretValue"; then
        echo "✓ Lambda has Secrets Manager permissions in policy: $policy_name"
        SECRET_PERMISSION_FOUND=true
        break
    fi
done

if [ "$SECRET_PERMISSION_FOUND" = false ]; then
    echo "WARNING: Secrets Manager permissions not found in inline policies"
fi

# Test SNS permissions
echo "Checking SNS permissions..."
SNS_PERMISSION_FOUND=false

for policy_name in $INLINE_POLICIES; do
    POLICY_DOC=$(aws iam get-role-policy \
        --role-name "$LAMBDA_ROLE_NAME" \
        --policy-name "$policy_name" \
        --query 'PolicyDocument' \
        --output text 2>/dev/null || echo "")
    
    if echo "$POLICY_DOC" | grep -q "sns:Publish"; then
        echo "✓ Lambda has SNS publish permissions in policy: $policy_name"
        SNS_PERMISSION_FOUND=true
        break
    fi
done

if [ "$SNS_PERMISSION_FOUND" = false ]; then
    echo "WARNING: SNS publish permissions not found in inline policies"
fi

# Test VPC permissions (EC2 permissions for ENI management)
echo "Checking VPC permissions..."
VPC_PERMISSION_FOUND=false

for policy_name in $INLINE_POLICIES; do
    POLICY_DOC=$(aws iam get-role-policy \
        --role-name "$LAMBDA_ROLE_NAME" \
        --policy-name "$policy_name" \
        --query 'PolicyDocument' \
        --output text 2>/dev/null || echo "")
    
    if echo "$POLICY_DOC" | grep -q "ec2:CreateNetworkInterface\|ec2:DescribeNetworkInterfaces"; then
        echo "✓ Lambda has VPC permissions in policy: $policy_name"
        VPC_PERMISSION_FOUND=true
        break
    fi
done

if [ "$VPC_PERMISSION_FOUND" = false ] && [ -z "$BASIC_POLICY" ]; then
    echo "WARNING: VPC permissions not found - Lambda may not be able to access VPC resources"
fi

# Test RDS instance access (indirectly through security group)
echo "Checking RDS access configuration..."
DB_IDENTIFIER=$(aws rds describe-db-instances \
    --query 'DBInstances[?contains(DBInstanceIdentifier,`csv-processor`)].DBInstanceIdentifier' \
    --output text --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -n "$DB_IDENTIFIER" ]; then
    DB_SG=$(aws rds describe-db-instances \
        --db-instance-identifier "$DB_IDENTIFIER" \
        --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
        --output text --region "$AWS_REGION")
    
    if [ -n "$DB_SG" ]; then
        echo "✓ RDS instance security group configured: $DB_SG"
    fi
fi

# Test Lambda function configuration for VPC
echo "Checking Lambda VPC configuration..."
LAMBDA_VPC_CONFIG=$(aws lambda get-function \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --query 'Configuration.VpcConfig.VpcId' \
    --output text --region "$AWS_REGION")

if [ "$LAMBDA_VPC_CONFIG" = "None" ] || [ -z "$LAMBDA_VPC_CONFIG" ]; then
    echo "WARNING: Lambda is not configured for VPC access"
else
    echo "✓ Lambda is configured for VPC access: $LAMBDA_VPC_CONFIG"
fi

echo "✅ Permissions validation test completed!"