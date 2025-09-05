# CI/CD Pipeline Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              CI/CD PIPELINE                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────────────┐ │
│  │   GitHub Repo   │    │ GitHub Actions   │    │       AWS Resources         │ │
│  │                 │    │                  │    │                             │ │
│  │ • Lambda code   │───▶│ Composite Actions│───▶│ • Lambda Function           │ │
│  │ • Workflow YAML │    │ • package-lambda │    │ • S3 Buckets               │ │
│  │ • Terraform     │    │ • terraform-     │    │ • RDS Instance             │ │
│  │   files (.tf)   │    │   deploy         │    │ • SNS Topic                │ │
│  │ • Composite     │    │ • Trigger: PR    │    │ • CloudWatch Alarms        │ │
│  │   Actions       │    │   to master      │    │ • VPC & Security           │ │
│  └─────────────────┘    └──────────────────┘    └─────────────────────────────┘ │
│                                                                                 │
│                          Branch Protection                                      │
│                          ┌─────────────────┐                                   │
│                          │ Master Branch   │                                   │
│                          │ • No direct     │                                   │
│                          │   pushes        │                                   │
│                          │ • PR required   │                                   │
│                          │ • 1 approval    │                                   │
│                          └─────────────────┘                                   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Pipeline Components

### Composite Actions
- **package-lambda**: Simplified Lambda packaging action
  - Creates temporary directory
  - Copies Lambda code and installs dependencies
  - Creates deployment zip
- **terraform-deploy**: Simplified infrastructure deployment
  - Terraform init, validate, plan, apply workflow
  - Shows plan output for visibility

### Branch Protection & PR Workflow
- **Master Branch Protection**: Prevents direct pushes
- **PR Requirements**: 1 approval required before merge
- **Automated Testing**: Each PR triggers full pipeline validation
- **Merge-based Deployment**: Only approved PRs can deploy to production

## Code Change Flow

1. **Developer creates feature branch** with changes
2. **Create Pull Request** targeting master branch
3. **Pipeline triggers** on PR creation/updates:
   - Package Lambda function
   - Run Terraform plan (validation only)
   - Show infrastructure changes
4. **Code review & approval** (1 reviewer required)
5. **Merge PR to master** triggers production deployment
6. **Infrastructure updated** automatically via Terraform apply