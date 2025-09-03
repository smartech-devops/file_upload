# CI/CD Pipeline Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              CI/CD PIPELINE                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────────────┐ │
│  │   GitHub Repo   │    │ GitHub Actions   │    │       AWS Resources         │ │
│  │                 │    │                  │    │                             │ │
│  │ • Lambda code   │───▶│ • Package code   │───▶│ • Lambda Function           │ │
│  │ • Workflow YAML │    │ • Deploy Lambda  │    │ • S3 Buckets               │ │
│  │ • Terraform     │    │ • Run Terraform  │    │ • RDS Instance             │ │
│  │   files (.tf)   │    │ • Trigger: push  │    │ • SNS Topic                │ │
│  │                 │    │   to main        │    │ • CloudWatch Alarms        │ │
│  └─────────────────┘    └──────────────────┘    └─────────────────────────────┘ │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```


## Terraform Infrastructure Components

- **S3 Buckets**: candidate-test-input, candidate-test-output, candidate-test-backup
- **Lambda Function**: CSV processor with S3 trigger
- **RDS Instance**: PostgreSQL database with VPC and security groups
- **Secrets Manager**: Database credentials storage
- **SNS Topic**: Notifications with email subscription
- **CloudWatch Alarms**: Error and duration monitoring
- **IAM Roles**: Lambda execution role with necessary permissions

## Bootstrap Process

See [Bootstrap Process Design](../bootstrap/bootstrap-process.md) for detailed setup instructions.

## Code Change Flow

**Before Change**: Lambda returns `rows_count`
**After Change**: Lambda returns `file_size_kb`
**Pipeline**: GitHub Actions automatically redeploys the updated Lambda