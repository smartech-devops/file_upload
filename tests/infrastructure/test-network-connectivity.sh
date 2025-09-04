#!/bin/bash

# Test: Network Connectivity
# Validates VPC peering, security groups, and network routes

set -e

echo "Testing network connectivity..."

# Test VPC peering connection
echo "Checking VPC peering connection..."
PEERING_ID=$(aws ec2 describe-vpc-peering-connections \
    --filters "Name=status-code,Values=active" \
    --query 'VpcPeeringConnections[?Tags[?Key==`Name` && contains(Value,`csv-processor`)]].VpcPeeringConnectionId' \
    --output text --region "$AWS_REGION")

if [ -z "$PEERING_ID" ]; then
    echo "ERROR: No active VPC peering connection found"
    exit 1
fi

echo "✓ VPC peering connection found: $PEERING_ID"

# Test Lambda security group egress rules
echo "Checking Lambda security group..."
LAMBDA_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=csv-processor-lambda" \
    --query 'SecurityGroups[0].GroupId' \
    --output text --region "$AWS_REGION")

if [ "$LAMBDA_SG_ID" = "None" ] || [ -z "$LAMBDA_SG_ID" ]; then
    echo "ERROR: Lambda security group not found"
    exit 1
fi

echo "✓ Lambda security group found: $LAMBDA_SG_ID"

# Test RDS security group ingress rules
echo "Checking RDS security group..."
RDS_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=csv-processor-rds" \
    --query 'SecurityGroups[0].GroupId' \
    --output text --region "$AWS_REGION")

if [ "$RDS_SG_ID" = "None" ] || [ -z "$RDS_SG_ID" ]; then
    echo "ERROR: RDS security group not found"
    exit 1
fi

# Check if RDS security group allows PostgreSQL traffic from Lambda VPC
INGRESS_RULE=$(aws ec2 describe-security-groups \
    --group-ids "$RDS_SG_ID" \
    --query 'SecurityGroups[0].IpPermissions[?FromPort==`5432` && ToPort==`5432`].IpRanges[?CidrIp==`10.0.0.0/16`]' \
    --output text --region "$AWS_REGION")

if [ -z "$INGRESS_RULE" ]; then
    echo "ERROR: RDS security group does not allow PostgreSQL traffic from Lambda VPC"
    exit 1
fi

echo "✓ RDS security group configured correctly: $RDS_SG_ID"

# Test route tables
echo "Checking route tables..."

# Check Lambda VPC route table for RDS VPC route
LAMBDA_RT_ID=$(aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=csv-processor-lambda-to-rds-route-table" \
    --query 'RouteTables[0].RouteTableId' \
    --output text --region "$AWS_REGION")

if [ "$LAMBDA_RT_ID" = "None" ] || [ -z "$LAMBDA_RT_ID" ]; then
    echo "ERROR: Lambda route table not found"
    exit 1
fi

# Check if route to RDS VPC exists
RDS_ROUTE=$(aws ec2 describe-route-tables \
    --route-table-ids "$LAMBDA_RT_ID" \
    --query 'RouteTables[0].Routes[?DestinationCidrBlock==`10.1.0.0/16`].VpcPeeringConnectionId' \
    --output text --region "$AWS_REGION")

if [ -z "$RDS_ROUTE" ]; then
    echo "ERROR: No route from Lambda VPC to RDS VPC found"
    exit 1
fi

echo "✓ Lambda to RDS route configured: $LAMBDA_RT_ID"

# Check RDS VPC route table for Lambda VPC route
RDS_RT_ID=$(aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=csv-processor-rds-to-lambda-route-table" \
    --query 'RouteTables[0].RouteTableId' \
    --output text --region "$AWS_REGION")

if [ "$RDS_RT_ID" = "None" ] || [ -z "$RDS_RT_ID" ]; then
    echo "ERROR: RDS route table not found"
    exit 1
fi

# Check if route to Lambda VPC exists
LAMBDA_ROUTE=$(aws ec2 describe-route-tables \
    --route-table-ids "$RDS_RT_ID" \
    --query 'RouteTables[0].Routes[?DestinationCidrBlock==`10.0.0.0/16`].VpcPeeringConnectionId' \
    --output text --region "$AWS_REGION")

if [ -z "$LAMBDA_ROUTE" ]; then
    echo "ERROR: No route from RDS VPC to Lambda VPC found"
    exit 1
fi

echo "✓ RDS to Lambda route configured: $RDS_RT_ID"

# Test Internet Gateways for public subnets
echo "Checking Internet Gateways..."

LAMBDA_IGW=$(aws ec2 describe-internet-gateways \
    --filters "Name=tag:Name,Values=csv-processor-lambda-igw" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text --region "$AWS_REGION")

if [ "$LAMBDA_IGW" = "None" ] || [ -z "$LAMBDA_IGW" ]; then
    echo "ERROR: Lambda Internet Gateway not found"
    exit 1
fi

echo "✓ Lambda Internet Gateway found: $LAMBDA_IGW"

RDS_IGW=$(aws ec2 describe-internet-gateways \
    --filters "Name=tag:Name,Values=csv-processor-rds-igw" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text --region "$AWS_REGION")

if [ "$RDS_IGW" = "None" ] || [ -z "$RDS_IGW" ]; then
    echo "ERROR: RDS Internet Gateway not found"
    exit 1
fi

echo "✓ RDS Internet Gateway found: $RDS_IGW"

echo "✅ Network connectivity test passed!"