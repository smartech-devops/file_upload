import json
import csv
import boto3
import os
from datetime import datetime
import psycopg2
from urllib.parse import unquote_plus

# AWS clients
s3_client = boto3.client('s3')
sns_client = boto3.client('sns')
secrets_client = boto3.client('secretsmanager')

def lambda_handler(event, context):
    """
    Lambda function to process CSV files uploaded to S3
    """
    try:
        # Parse S3 event
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = unquote_plus(event['Records'][0]['s3']['object']['key'])
        
        print(f"Processing file: {key} from bucket: {bucket}")
        
        # Download file from S3
        response = s3_client.get_object(Bucket=bucket, Key=key)
        csv_content = response['Body'].read().decode('utf-8')
        
        # Calculate file size in KB
        file_size_bytes = len(csv_content.encode('utf-8'))
        file_size_kb = round(file_size_bytes / 1024, 2)
        
        print(f"CSV file size: {file_size_kb} KB")
        
        # Get database credentials from Secrets Manager
        db_credentials = get_db_credentials()
        
        # Store metadata in RDS
        store_file_metadata(key, db_credentials)
        
        # Create result file
        result = {
            "filename": key,
            "file_size_kb": file_size_kb,
            "status": "success"
        }
        
        # Upload result to output bucket
        output_bucket = os.environ['OUTPUT_BUCKET']
        result_key = f"result_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        s3_client.put_object(
            Bucket=output_bucket,
            Key=result_key,
            Body=json.dumps(result, indent=2),
            ContentType='application/json'
        )
        
        # Backup original file
        backup_bucket = os.environ['BACKUP_BUCKET']
        backup_key = f"backup/{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}_{key}"
        
        s3_client.copy_object(
            CopySource={'Bucket': bucket, 'Key': key},
            Bucket=backup_bucket,
            Key=backup_key
        )
        
        # Send SNS notification
        send_notification(result, success=True)
        
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
        
    except Exception as e:
        print(f"Error processing file: {str(e)}")
        
        # Send error notification
        error_result = {
            "filename": key if 'key' in locals() else "unknown",
            "error": str(e),
            "processed_at": datetime.now().isoformat(),
            "status": "error"
        }
        
        send_notification(error_result, success=False)
        
        return {
            'statusCode': 500,
            'body': json.dumps(error_result)
        }

def get_db_credentials():
    """Get database credentials from Secrets Manager"""
    secret_name = os.environ['DB_SECRET_NAME']
    
    response = secrets_client.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])

def store_file_metadata(filename, db_credentials):
    """Store file metadata in RDS PostgreSQL"""
    connection = None
    try:
        connection = psycopg2.connect(
            host=db_credentials['host'],
            database=db_credentials['dbname'],
            user=db_credentials['username'],
            password=db_credentials['password'],
            port=db_credentials['port']
        )
        
        cursor = connection.cursor()
        
        # Create table if it doesn't exist
        create_table_query = """
        CREATE TABLE IF NOT EXISTS file_metadata (
            id SERIAL PRIMARY KEY,
            filename VARCHAR(255) NOT NULL,
            status VARCHAR(50) NOT NULL,
            timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
        cursor.execute(create_table_query)
        
        # Create indexes if they don't exist
        create_indexes = [
            "CREATE INDEX IF NOT EXISTS idx_file_metadata_filename ON file_metadata(filename)",
            "CREATE INDEX IF NOT EXISTS idx_file_metadata_timestamp ON file_metadata(timestamp)",
            "CREATE INDEX IF NOT EXISTS idx_file_metadata_status ON file_metadata(status)"
        ]
        
        for index_query in create_indexes:
            cursor.execute(index_query)
        
        # Insert file metadata
        insert_query = """
        INSERT INTO file_metadata (filename, status, timestamp)
        VALUES (%s, %s, %s)
        """
        
        cursor.execute(insert_query, (
            filename,
            'processed',
            datetime.now()
        ))
        
        connection.commit()
        print(f"Stored metadata for file: {filename}")
        
    except Exception as e:
        print(f"Database error: {str(e)}")
        raise e
    finally:
        if connection:
            connection.close()

def send_notification(result, success=True):
    """Send SNS notification"""
    topic_arn = os.environ['SNS_TOPIC_ARN']
    
    if success:
        subject = f"CSV Processing Success - {result['filename']}"
        message = f"""
File processing completed successfully.

Filename: {result['filename']}
File Size (KB): {result['file_size_kb']}
Status: {result['status']}
        """
    else:
        subject = f"CSV Processing Error - {result['filename']}"
        message = f"""
File processing failed.

Filename: {result['filename']}
Error: {result['error']}
Processed At: {result['processed_at']}
Status: {result['status']}
        """
    
    sns_client.publish(
        TopicArn=topic_arn,
        Subject=subject,
        Message=message
    )
    
    print(f"SNS notification sent: {subject}")