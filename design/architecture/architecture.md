# AWS Data Processing Pipeline - Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                AWS CLOUD                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────────────┐ │
│  │   S3 Bucket     │    │                  │    │         RDS                 │ │
│  │candidate-test-  │    │                  │    │     PostgreSQL              │ │
│  │    input        │    │     LAMBDA       │    │                             │ │
│  │                 │───▶│    FUNCTION      │───▶│  ┌─────────────────────┐   │ │
│  │ CSV files       │    │                  │    │  │ file_metadata table │   │ │
│  │ uploaded here   │    │ • Process CSV    │    │  │ - id (SERIAL)       │   │ │
│  │                 │    │ • Count rows     │    │  │ - filename          │   │ │
│  └─────────────────┘    │ • Insert to RDS  │    │  │ - status            │   │ │
│                          │ • Write output   │    │  │ - timestamp         │   │ │
│                          │ • Backup file    │    │  └─────────────────────┘   │ │
│                          │ • Send SNS       │    │                             │ │
│                          └──┬───┬───┬──────┘    └─────────────────────────────┘ │
│                             │   │   │                                           │ │
│                             │   │   │           ┌─────────────────────────────┐ │
│                             │   │   │           │   S3 Output Bucket          │ │
│                             │   │   └──────────▶│ candidate-test-output       │ │
│                             │   │               │                             │ │
│                             │   │               │ result.json files           │ │
│                             │   │               │ (processing results)        │ │
│                             │   │               └─────────────────────────────┘ │
│                             │   │                                               │ │
│                             │   │               ┌─────────────────────────────┐ │
│                             │   │               │      Secrets Manager        │ │
│                             │   │               │                             │ │
│                             │   │◄──────────────│  DB Connection String       │ │
│                             │                   │  Username & Password        │ │
│                             │                   └─────────────────────────────┘ │
│                             │                                                   │ │
│                             └───┐                                               │ │
│                                 │                                               │ │
│  ┌─────────────────────────┐     │               ┌─────────────────────────────┐ │
│  │      Backup Bucket      │     │               │         SNS Topic           │ │
│  │ candidate-test-backup   │     │               │    (SHARED TOPIC)           │ │
│  │                         │     │               │                             │ │
│  │ backup/2025-09-02_14-   │◄────┤               │  ┌─────────────────────┐   │ │
│  │ 30-00_data.csv          │     │               │  │ Email Subscription  │   │ │
│  │                         │     └──────────────▶│  │ (interviewer email) │   │ │
│  │ (timestamped files)     │                     │  └─────────────────────┘   │ │
│  └─────────────────────────┘                     └─────────────┬───────────────────┘ │
│                                                                │                     │ │
│                                                                ▼                     │ │
│  ┌──────────────────────────┐                          ▲                            │ │
│  │   CloudWatch Alarms      │──────────────────────────┘                            │ │
│  │                          │                                                       │
│  │ ┌──────────┐ ┌─────────┐ │                                                        │ │
│  │ │Error >0  │ │Dur. >5s │ │                                                        │ │
│  │ │Alarm     │ │Alarm    │ │                                                        │ │
│  │ └──────────┘ └─────────┘ │                                                        │ │
│  └──────────────────────────┘                                                        │ │
│                                                                                      │ │
│                                                                ▼                    │ │
│                                                         📧 EMAIL NOTIFICATION     │ │
│                                                            (Success/Failure)      │ │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

1. **Upload**: CSV file uploaded to S3 bucket (candidate-test-input)
2. **Trigger**: S3 event triggers Lambda function automatically
3. **Process**: Lambda reads CSV, counts rows, stores metadata in RDS
4. **Output**: Lambda writes result.json to output bucket (candidate-test-output)
5. **Backup**: Lambda copies file to backup bucket with timestamp
6. **Notify**: Lambda publishes result to SNS → Email sent to interviewer
7. **Monitor**: CloudWatch alarms monitor Lambda errors and duration → Send alerts to SNS
8. **Deploy**: GitHub Actions automatically deploys code changes to Lambda