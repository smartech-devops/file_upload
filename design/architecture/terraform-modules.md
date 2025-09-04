# Terraform Module Structure Design

## Overview
Modular Terraform architecture for the AWS Data Processing Pipeline, designed to demonstrate advanced Terraform knowledge and best practices.

## Module Structure

```
terraform/
├── backend.tf              # S3 backend configuration
├── main.tf                # Root module - calls all child modules
├── variables.tf           # Root variables
├── outputs.tf            # Root outputs
└── modules/
    ├── networking/
    │   ├── main.tf        # VPCs, subnets, peering, security groups
    │   ├── variables.tf   # Network variables (CIDR blocks, etc.)
    │   └── outputs.tf     # VPC IDs, subnet IDs, security group IDs
    ├── storage/
    │   ├── main.tf        # S3 buckets, notifications, Lambda permissions
    │   ├── variables.tf   # Bucket prefixes, Lambda function name
    │   └── outputs.tf     # Bucket names and ARNs
    ├── database/
    │   ├── main.tf        # RDS instance, secrets manager, random password
    │   ├── variables.tf   # DB instance class, engine version, etc.
    │   └── outputs.tf     # DB endpoint, secret ARN
    ├── compute/
    │   ├── main.tf        # Lambda function, IAM roles, CloudWatch logs
    │   ├── variables.tf   # Runtime, timeout, environment variables
    │   └── outputs.tf     # Lambda function name and ARN
    └── monitoring/
        ├── main.tf        # SNS topic, CloudWatch alarms
        ├── variables.tf   # Email address, alarm thresholds
        └── outputs.tf     # SNS topic ARN
```

## Module Responsibilities

### 1. Networking Module
**Purpose**: Network isolation and connectivity
- **Resources**:
  - Lambda VPC (10.0.0.0/16) with private subnets
  - RDS VPC (10.1.0.0/16) with private subnets
  - VPC peering connection with route tables
  - Security groups for Lambda and RDS
- **Outputs**: VPC IDs, subnet IDs, security group IDs for other modules

### 2. Storage Module
**Purpose**: File storage and event processing
- **Resources**:
  - S3 input bucket (with CSV upload triggers)
  - S3 output bucket (for processing results)
  - S3 backup bucket (for file archiving)
  - S3 bucket notifications to Lambda
  - Lambda permissions for S3 access
- **Dependencies**: Requires Lambda function ARN from compute module
- **Outputs**: Bucket names and ARNs for Lambda environment variables

### 3. Database Module
**Purpose**: Data persistence and credential management
- **Resources**:
  - RDS PostgreSQL instance
  - DB subnet group using networking module outputs
  - Random password generation
  - Secrets Manager secret for DB credentials
  - Secret version with connection details
- **Dependencies**: Requires VPC and subnet IDs from networking module
- **Outputs**: Database endpoint, secret ARN for Lambda access

### 4. Compute Module
**Purpose**: Serverless processing logic
- **Resources**:
  - Lambda function with VPC configuration
  - Lambda execution IAM role and policies
  - CloudWatch log group for Lambda logs
  - Environment variables for S3/RDS/SNS integration
- **Dependencies**: Requires outputs from all other modules
- **Outputs**: Lambda function name and ARN for S3 notifications

### 5. Monitoring Module
**Purpose**: Notifications and alerting
- **Resources**:
  - SNS topic for notifications
  - Email subscription to SNS topic
  - CloudWatch alarms for Lambda errors and duration
- **Dependencies**: Requires Lambda function name from compute module
- **Outputs**: SNS topic ARN for Lambda environment variables

## Module Dependencies Graph

```
networking (base layer)
    ↓
database ← storage → compute ← monitoring
    ↓        ↓         ↑
    └────────┴─────────┘
         (all feed into compute)
```

## Root Module Configuration

### main.tf Structure
```hcl
module "networking" { ... }
module "database" { 
  depends_on = [module.networking]
  # networking outputs as inputs
}
module "storage" { ... }
module "compute" {
  depends_on = [module.networking, module.database, module.storage]
  # All module outputs as inputs
}
module "monitoring" {
  depends_on = [module.compute]
  # compute outputs as inputs
}
```

### Variable Flow
- **Root variables** → Module variables
- **Module outputs** → Other module inputs
- **Final outputs** → Root outputs

## Benefits for Interview Demonstration

### Advanced Terraform Knowledge
- **Module composition** and **reusability**
- **Clean interfaces** via variables/outputs
- **Dependency management** with explicit depends_on
- **Separation of concerns** by logical boundaries

### Best Practices
- **Single responsibility** per module
- **Explicit dependencies** between modules  
- **Consistent naming** conventions
- **Proper variable validation** and types

### Scalability Features
- **Reusable modules** for different environments
- **Configurable parameters** via variables
- **Environment-specific** variable files
- **Easy to extend** with new modules

### Production Readiness
- **Proper resource tagging** strategy
- **Security group** isolation
- **IAM least privilege** principles
- **Resource naming** conventions

## Interview Talking Points

1. **Why modules?** - Reusability, maintainability, team collaboration
2. **Dependency management** - Explicit vs implicit dependencies
3. **Module boundaries** - How to decide what goes in each module
4. **Variable design** - Required vs optional, validation, sensitive values
5. **Output strategy** - What to expose, naming conventions
6. **Testing approach** - How to test individual modules vs complete stack
7. **CI/CD integration** - Module versioning, environment promotion

## Future Enhancements

- **Remote module registry** for sharing across projects
- **Module versioning** with semantic versioning
- **Multi-environment** support (dev/staging/prod)
- **Conditional resources** based on environment
- **Data validation** with variable validation rules
- **Module documentation** with terraform-docs