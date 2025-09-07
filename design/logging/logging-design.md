# Logging Design Document

## Overview

This document outlines the comprehensive logging strategy for the CSV File Upload System, covering application logs, database logs, infrastructure logs, and monitoring.

## Current Logging Components

### 1. Lambda Function Logging

#### CloudWatch Log Group
- **Location**: `/aws/lambda/csv-processor`
- **Retention**: Configurable via `log_retention_days` variable
- **Content**: Application logs, error messages, processing metrics

#### Application Logging Strategy
The Lambda function uses Python `print()` statements that automatically flow to CloudWatch:

```python
# Current logging patterns in lambda_function.py:
print(f"Processing file: {key} from bucket: {bucket}")
print(f"CSV file size: {file_size_kb} KB")
print(f"Error processing file: {str(e)}")
print(f"Stored metadata for file: {filename}")
print(f"Database error: {str(e)}")
print(f"SNS notification sent: {subject}")
```

### 2. RDS PostgreSQL Logging

#### Parameter Group Configuration
- **Name**: `{db_identifier}-logging`
- **Family**: `postgres15`

#### Enabled Logging Parameters
- `log_statement = "all"` - Logs all SQL statements (DDL, DML)
- `log_min_duration_statement = "0"` - Logs all queries regardless of duration
- `log_connections = "1"` - Logs connection attempts
- `log_disconnections = "1"` - Logs disconnections
- `log_checkpoints = "1"` - Logs checkpoint operations
- `log_lock_waits = "1"` - Logs lock wait events

### 3. Infrastructure Monitoring

#### CloudWatch Alarms
- **Lambda Error Alarm**: Monitors function errors
- **Lambda Duration Alarm**: Monitors execution time
- **SNS Integration**: Alerts sent to configured email addresses

## Log Categories

### Application Logs
- **File Processing Events**: Upload, processing start/end, success/failure
- **Data Validation**: Schema validation, data quality checks
- **Performance Metrics**: Processing time, file size, record counts
- **Error Handling**: Detailed error messages with context

### Database Logs
- **Connection Events**: Successful/failed connections
- **Query Execution**: All SQL statements with parameters
- **Performance**: Slow query identification (currently logs all queries)
- **Security**: Authentication attempts, privilege escalation

### Infrastructure Logs
- **S3 Events**: Object creation, deletion, access patterns
- **Lambda Metrics**: Invocation count, duration, memory usage, errors
- **Network**: VPC flow logs (if enabled)
- **Security**: CloudTrail for API calls (if enabled)

## Log Levels and Structured Logging

### Current State
- Lambda uses basic print statements
- No structured logging format
- Limited log levels

### Recommended Enhancement
```python
import logging
import json
from datetime import datetime

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Structured log entry example
def log_processing_event(event_type, filename, details=None):
    log_entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "event_type": event_type,
        "filename": filename,
        "details": details or {}
    }
    logger.info(json.dumps(log_entry))
```

## Log Retention and Storage

### Current Retention Policies
- **Lambda Logs**: Configurable via Terraform variable
- **RDS Logs**: Default AWS retention (typically 7 days)

### Recommended Retention Strategy
- **Error Logs**: 90 days
- **Access Logs**: 30 days
- **Debug Logs**: 7 days
- **Audit Logs**: 1 year
- **Compliance Logs**: As per regulatory requirements

## Security and Compliance

### Data Sensitivity
- **PII Handling**: Ensure no personally identifiable information in logs
- **Credentials**: Never log passwords, API keys, or tokens
- **Data Samples**: Limit or hash sensitive data in logs

### Access Control
- **CloudWatch Logs**: IAM-based access control
- **RDS Logs**: Database-level permissions
- **Log Aggregation**: Centralized access control

## Monitoring and Alerting

### Current Alerts
- Lambda function errors
- Lambda execution duration exceeding threshold
- SNS notifications for critical events

### Enhanced Monitoring Opportunities
- **Database Connection Pool**: Monitor connection usage
- **File Processing Pipeline**: Track processing pipeline health
- **Data Quality**: Alert on validation failures
- **Performance Degradation**: Trend analysis for processing times

## Log Analysis and Observability

### Current Tools
- AWS CloudWatch for log viewing and basic queries
- CloudWatch Alarms for threshold monitoring

### Potential Enhancements
- **Log Insights**: Advanced querying and analysis
- **Dashboards**: Visual representation of system health
- **Correlation**: Link application logs with infrastructure metrics
- **Anomaly Detection**: ML-based anomaly detection

## Cost Optimization

### Current Costs
- CloudWatch log storage and ingestion
- Log retention costs based on volume and duration

### Optimization Strategies
- **Log Level Filtering**: Reduce verbose debug logs in production
- **Sampling**: Sample high-volume logs for analysis
- **Archival**: Move old logs to cheaper storage (S3, Glacier)
- **Compression**: Enable log compression where available

## Implementation Roadmap

### Phase 1: Immediate Improvements
1. Implement structured logging in Lambda function
2. Add log levels (DEBUG, INFO, WARN, ERROR)
3. Review and optimize RDS logging parameters

### Phase 2: Enhanced Monitoring
1. Create CloudWatch dashboards
2. Implement custom metrics
3. Set up log-based alarms

### Phase 3: Advanced Analytics
1. Implement Log Insights queries
2. Set up automated reporting
3. Integrate with external monitoring tools

## Configuration Management

### Terraform Variables
```hcl
variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
}

variable "enable_debug_logging" {
  description = "Enable debug level logging"
  type        = bool
  default     = false
}

variable "rds_log_retention_days" {
  description = "RDS log retention period in days"
  type        = number
  default     = 7
}
```

## Best Practices

### Application Logging
1. Use appropriate log levels
2. Include contextual information (request ID, user ID, file name)
3. Log entry and exit points of critical functions
4. Include timing information for performance analysis

### Database Logging
1. Balance between visibility and performance impact
2. Consider log volume and storage costs
3. Separate audit logs from performance logs
4. Regular log analysis for optimization opportunities

### Security
1. Implement log tampering protection
2. Encrypt logs in transit and at rest
3. Regular access audits
4. Incident response procedures

## Troubleshooting Guide

### Common Issues
1. **High Log Volume**: Adjust log levels and retention
2. **Missing Logs**: Check IAM permissions and log group configuration
3. **Performance Impact**: Review logging parameters, especially for RDS
4. **Cost Overruns**: Implement log sampling and retention policies

### Debugging Steps
1. Check CloudWatch Log Groups exist and are properly configured
2. Verify IAM permissions for log writing
3. Review Lambda function timeout and memory settings
4. Validate RDS parameter group is applied correctly

## Conclusion

The current logging implementation provides basic visibility into system operations. The comprehensive logging strategy outlined in this document will enhance observability, improve troubleshooting capabilities, and provide better insights into system performance and security.

Regular review and optimization of logging configuration should be part of the operational maintenance cycle to balance visibility, performance, and cost considerations.