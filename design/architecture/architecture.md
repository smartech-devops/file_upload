# AWS Data Processing Pipeline - Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                AWS CLOUD                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│ ┌──────────── LAMBDA VPC (10.0.0.0/16) ──────────────────────────────────────┐ │
│ │                                                                              │ │
│ │  ┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────────┐ │ │
│ │  │   S3 Bucket     │    │                  │    │      Secrets Manager   │ │ │
│ │  │candidate-test-  │    │     LAMBDA       │    │                         │ │ │
│ │  │    input        │    │    FUNCTION      │    │  DB Connection String  │ │ │
│ │  │                 │───▶│                  │◄───│  Username & Password   │ │ │
│ │  │ CSV files       │    │  • Process CSV   │    └─────────────────────────┘ │ │
│ │  │ uploaded here   │    │  • Count rows    │                                │ │
│ │  │                 │    │  • Insert to RDS │    ┌─────────────────────────┐ │ │
│ │  └─────────────────┘    │  • Write output  │    │   S3 Output Bucket     │ │ │
│ │                         │  • Backup file   │───▶│ candidate-test-output  │ │ │
│ │  ┌─────────────────────┐ │  • Send SNS      │    │                        │ │ │
│ │  │   Backup Bucket     │ │                  │    │ result.json files      │ │ │
│ │  │candidate-test-backup│◄┤                  │    │ (processing results)   │ │ │
│ │  │                     │ └──────────────────┘    └─────────────────────────┘ │ │
│ │  │ backup/timestamp... │                                                    │ │
│ │  └─────────────────────┘                                                    │ │
│ │                                    │                                        │ │
│ │                                    ▼                                        │ │
│ │  ┌─────────────────────────────────┐                                     │  │ │
│ │  │        SNS Topic                │                                     │  │ │
│ │  │    (SHARED TOPIC)               │                                     │  │ │
│ │  │                                 │                                     │  │ │
│ │  │  Email: smartech.devops.test    │                                     │  │ │
│ │  │  @gmail.com                     │                                     │  │ │
│ │  │                                 │                                     │  │ │
│ │  │             │                   │                                     │  │ │
│ │  │             ▼                   │                                     │  │ │
│ │  │      📧 EMAIL NOTIFICATION      │                                     │  │ │
│ │  │         (Success/Failure)       │                                     │  │ │
│ │  └─────────────────────────────────┘                                     │  │ │
│ │                    ▲                                                      │  │ │
│ │                    │                                                      │  │ │
│ │  ┌─────────────────┼──────────────────────────┐                          │  │ │
│ │  │   CloudWatch Alarms             │          │                          │  │ │
│ │  │                                 │          │                          │  │ │
│ │  │ ┌──────────┐ ┌─────────┐        │          │                          │  │ │
│ │  │ │Error >0  │ │Dur. >5s │        │          │                          │  │ │
│ │  │ │Alarm     │ │Alarm    │────────┘          │                          │  │ │
│ │  │ └──────────┘ └─────────┘                   │                          │  │ │
│ │  └─────────────────────────────────────────────┘                          │  │ │
│ └──────────────────────────────────────────────────────────────────────────────────┘ │
│                                           │                                          │
│                                           │ VPC PEERING                              │
│                                           ▼                                          │
│ ┌─────────────── RDS VPC (10.1.0.0/16) ────────────────────────────────────────┐   │
│ │                                                                               │   │
│ │                         ┌─────────────────────────────┐                      │   │
│ │                         │         RDS                 │                      │   │
│ │                         │     PostgreSQL              │                      │   │
│ │                         │                             │                      │   │
│ │                         │  ┌─────────────────────┐   │                      │   │
│ │                         │  │ file_metadata table │   │                      │   │
│ │                         │  │ - id (SERIAL)       │   │                      │   │
│ │                         │  │ - filename          │   │                      │   │
│ │                         │  │ - status            │   │                      │   │
│ │                         │  │ - timestamp         │   │                      │   │
│ │                         │  │ - rows_count        │   │                      │   │
│ │                         │  └─────────────────────┘   │                      │   │
│ │                         └─────────────────────────────┘                      │   │
│ │                                                                               │   │
│ └───────────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Terraform Infrastructure Components

### Core Services
- **S3 Buckets**: candidate-test-input, candidate-test-output, candidate-test-backup
- **Lambda Function**: CSV processor with S3 trigger
- **RDS Instance**: PostgreSQL database with VPC and security groups
- **Secrets Manager**: Database credentials storage
- **SNS Topic**: Notifications with email subscription
- **CloudWatch Alarms**: Error and duration monitoring
- **IAM Roles**: Lambda execution role with necessary permissions

### Network Components
- **VPCs**: 
  - Lambda VPC (10.0.0.0/16) - Contains Lambda function and shared resources
  - RDS VPC (10.1.0.0/16) - Isolated database environment
- **VPC Peering**: Cross-VPC connectivity between Lambda and RDS VPCs
- **VPC Endpoints**: Private connectivity to AWS services (S3, Secrets Manager, SNS)
- **Internet Gateway**: Outbound internet access for Lambda VPC
- **Route Tables**: Custom routing for VPC peering and endpoint connectivity
- **Security Groups**: Network-level access control for resources
- **Subnets**: 
  - Private subnets for Lambda and RDS
  - Public subnets for NAT Gateway (if needed)



## Data Flow

1. **Upload**: CSV file uploaded to S3 bucket (candidate-test-input)
2. **Trigger**: S3 event triggers Lambda function automatically
3. **Process**: Lambda reads CSV, counts rows, stores metadata in RDS
4. **Output**: Lambda writes result.json to output bucket (candidate-test-output)
5. **Backup**: Lambda copies file to backup bucket with timestamp
6. **Notify**: Lambda publishes result to SNS → Email sent to interviewer
7. **Monitor**: CloudWatch alarms monitor Lambda errors and duration → Send alerts to SNS
8. **Deploy**: GitHub Actions automatically deploys code changes to Lambda