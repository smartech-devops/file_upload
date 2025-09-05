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

