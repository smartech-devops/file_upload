#!/bin/bash

# Test: Lambda RDS Connection
# Tests Lambda's ability to connect to RDS database

set -e

echo "Testing Lambda RDS connection..."

# Create a test script for Lambda to execute
TEST_LAMBDA_CODE='
import json
import boto3
import psycopg2
import os

def lambda_handler(event, context):
    try:
        # Get database credentials from Secrets Manager
        secrets_client = boto3.client("secretsmanager")
        secret_response = secrets_client.get_secret_value(
            SecretId=os.environ["DB_SECRET_NAME"]
        )
        
        secret_data = json.loads(secret_response["SecretString"])
        
        # Connect to database
        conn = psycopg2.connect(
            host=secret_data["host"],
            database=secret_data["dbname"],
            user=secret_data["username"],
            password=secret_data["password"],
            port=secret_data.get("port", 5432),
            connect_timeout=10
        )
        
        # Test basic query
        cursor = conn.cursor()
        cursor.execute("SELECT 1 as test_connection")
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Database connection successful",
                "test_result": result[0] if result else None
            })
        }
        
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": str(e),
                "message": "Database connection failed"
            })
        }
'

# Create test payload for Lambda
TEST_PAYLOAD='{"test": "database_connection"}'

echo "Invoking Lambda function to test database connection..."

# Invoke Lambda function synchronously
LAMBDA_RESPONSE=$(aws lambda invoke \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --payload "$TEST_PAYLOAD" \
    --region "$AWS_REGION" \
    --query 'StatusCode' \
    --output text \
    /tmp/lambda_response.json 2>/dev/null)

if [ "$LAMBDA_RESPONSE" != "200" ]; then
    echo "ERROR: Lambda invocation failed with status code: $LAMBDA_RESPONSE"
    exit 1
fi

echo "✓ Lambda invocation successful"

# Read and parse Lambda response
if [ -f "/tmp/lambda_response.json" ]; then
    RESPONSE_BODY=$(cat /tmp/lambda_response.json)
    echo "Lambda response: $RESPONSE_BODY"
    
    # Check if response indicates successful database connection
    if echo "$RESPONSE_BODY" | grep -q '"statusCode": 200' && echo "$RESPONSE_BODY" | grep -q "connection successful"; then
        echo "✓ Database connection test passed"
        CONNECTION_SUCCESS=true
    elif echo "$RESPONSE_BODY" | grep -q '"statusCode": 500' || echo "$RESPONSE_BODY" | grep -q "connection failed"; then
        echo "ERROR: Database connection failed"
        echo "Response: $RESPONSE_BODY"
        CONNECTION_SUCCESS=false
    else
        echo "WARNING: Unexpected Lambda response format"
        CONNECTION_SUCCESS=false
    fi
    
    rm -f /tmp/lambda_response.json
else
    echo "ERROR: No response file found"
    CONNECTION_SUCCESS=false
fi

# Alternative test: Check recent CloudWatch logs for database connection attempts
echo "Checking CloudWatch logs for database connection attempts..."
LOG_GROUP_NAME="/aws/lambda/$LAMBDA_FUNCTION_NAME"

# Get the most recent log stream
LATEST_LOG_STREAM=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP_NAME" \
    --order-by "LastEventTime" \
    --descending \
    --max-items 1 \
    --region "$AWS_REGION" \
    --query 'logStreams[0].logStreamName' \
    --output text 2>/dev/null || echo "")

if [ -n "$LATEST_LOG_STREAM" ] && [ "$LATEST_LOG_STREAM" != "None" ]; then
    # Get recent log events
    RECENT_LOGS=$(aws logs get-log-events \
        --log-group-name "$LOG_GROUP_NAME" \
        --log-stream-name "$LATEST_LOG_STREAM" \
        --start-time "$(($(date +%s) * 1000 - 300000))" \
        --region "$AWS_REGION" \
        --query 'events[].message' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$RECENT_LOGS" ]; then
        echo "✓ Retrieved recent Lambda logs"
        
        # Check for database connection indicators in logs
        if echo "$RECENT_LOGS" | grep -qi "connection\|database\|psycopg2\|postgres"; then
            echo "✓ Found database-related activity in logs"
        fi
        
        # Check for errors
        if echo "$RECENT_LOGS" | grep -qi "error\|exception\|failed"; then
            echo "WARNING: Found errors in Lambda logs"
            echo "Recent error logs:"
            echo "$RECENT_LOGS" | grep -i "error\|exception\|failed" | head -5
        fi
    fi
else
    echo "WARNING: Could not retrieve recent Lambda logs"
fi

# Test database instance accessibility
echo "Verifying database instance is accessible..."

# Get database endpoint
DB_IDENTIFIER=$(aws rds describe-db-instances \
    --query 'DBInstances[?contains(DBInstanceIdentifier,`csv-processor`)].DBInstanceIdentifier' \
    --output text --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -n "$DB_IDENTIFIER" ]; then
    DB_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier "$DB_IDENTIFIER" \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text --region "$AWS_REGION")
    
    DB_PORT=$(aws rds describe-db-instances \
        --db-instance-identifier "$DB_IDENTIFIER" \
        --query 'DBInstances[0].Endpoint.Port' \
        --output text --region "$AWS_REGION")
    
    echo "Database endpoint: $DB_ENDPOINT:$DB_PORT"
    echo "✓ Database instance found and has endpoint"
else
    echo "ERROR: Could not find RDS instance"
    exit 1
fi

# Test Secrets Manager access
echo "Testing Secrets Manager access..."
SECRET_VALUE=$(aws secretsmanager get-secret-value \
    --secret-id "$DB_SECRET_NAME" \
    --region "$AWS_REGION" \
    --query 'SecretString' \
    --output text 2>/dev/null || echo "")

if [ -n "$SECRET_VALUE" ]; then
    echo "✓ Successfully retrieved database secret"
    
    # Validate secret contains required fields
    if echo "$SECRET_VALUE" | grep -q '"host"' && echo "$SECRET_VALUE" | grep -q '"username"' && echo "$SECRET_VALUE" | grep -q '"password"'; then
        echo "✓ Database secret contains required fields"
    else
        echo "ERROR: Database secret missing required fields"
        exit 1
    fi
else
    echo "ERROR: Could not retrieve database secret"
    exit 1
fi

echo "✅ Lambda RDS connection test completed!"

# Return appropriate exit code
if [ "$CONNECTION_SUCCESS" = true ]; then
    echo "✅ Test passed - Lambda successfully connected to RDS"
    exit 0
else
    echo "❌ Test failed - Lambda could not connect to RDS"
    exit 1
fi