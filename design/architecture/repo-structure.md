## Repository Structure

```
file_upload/
├── bootstrap/                   # Bootstrap infrastructure setup
│   └── bootstrap.sh            # Bootstrap script for initial setup
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions CI/CD workflow
├── design/                     # Architecture and design documentation
│   ├── architecture/           # System architecture documentation
│   │   ├── architecture.md     # Overall system architecture
│   │   ├── network-architecture.md  # Network design documentation
│   │   ├── terraform-modules.md     # Terraform modules documentation
│   │   └── repo-structure.md   # Repository structure (this file)
│   ├── auth/                   # Authentication and authorization docs
│   │   ├── github-oidc-role.md # GitHub OIDC configuration
│   │   └── github-gmail-config.md  # Email configuration
│   ├── bootstrap/              # Bootstrap process documentation
│   │   ├── bootstrap-process.md # Bootstrap setup guide
│   │   └── s3-backend-setup.md # S3 backend configuration
│   ├── cicd/                   # CI/CD pipeline documentation
│   │   ├── cicd-pipeline.md    # CI/CD overview
│   │   └── deploy-workflow.md  # Deployment workflow details
│   ├── testing/                # Testing strategy and documentation
│   │   └── testing-strategy.md # Comprehensive testing approach
│   └── future-enhancements.md  # Future development suggestions
├── docs/                       # Additional documentation
├── lambda/                     # Lambda function source code
│   └── lambda_function.py      # Main Lambda function
├── terraform/                  # Infrastructure as Code
│   ├── modules/                # Terraform modules
│   │   ├── compute/           # Lambda function module
│   │   │   ├── main.tf        # Lambda resources
│   │   │   ├── variables.tf   # Module variables
│   │   │   └── outputs.tf     # Module outputs
│   │   ├── database/          # RDS database module
│   │   │   ├── main.tf        # RDS resources
│   │   │   ├── variables.tf   # Module variables
│   │   │   └── outputs.tf     # Module outputs
│   │   ├── monitoring/        # SNS and monitoring module
│   │   │   ├── main.tf        # Monitoring resources
│   │   │   ├── variables.tf   # Module variables
│   │   │   └── outputs.tf     # Module outputs
│   │   ├── networking/        # VPC and networking module
│   │   │   ├── main.tf        # VPC, subnets, security groups
│   │   │   ├── variables.tf   # Module variables
│   │   │   └── outputs.tf     # Module outputs
│   │   └── storage/           # S3 buckets module
│   │       ├── main.tf        # S3 bucket resources
│   │       ├── variables.tf   # Module variables
│   │       └── outputs.tf     # Module outputs
│   ├── policies/              # IAM policies directory
│   ├── backend.tf             # Terraform backend configuration
│   ├── main.tf                # Root module - calls all modules
│   ├── variables.tf           # Root module variables
│   └── outputs.tf             # Root module outputs
├── tests/                     # Test suite
│   ├── infrastructure/        # Infrastructure validation tests
│   │   ├── test-network-connectivity.sh    # Network connectivity tests
│   │   ├── test-resource-deployment.sh     # Resource deployment validation
│   │   └── test-permissions.sh             # Permission validation
│   ├── integration/           # Integration tests
│   │   ├── test-s3-lambda-trigger.sh       # S3 to Lambda trigger test
│   │   ├── test-lambda-rds-connection.sh   # Lambda to RDS connectivity
│   │   ├── test-end-to-end-workflow.sh     # Complete workflow test
│   │   └── test-error-handling.sh          # Error handling validation
│   ├── functional/            # Functional tests
│   │   ├── test-csv-processing.sh          # CSV processing functionality
│   │   ├── test-data-validation.sh         # Data validation tests
│   │   └── sample-data/                    # Test data files
│   │       ├── valid-sample.csv            # Well-formed test data
│   │       ├── invalid-sample.csv          # Invalid data for testing
│   │       ├── large-sample.csv            # Large content test data
│   │       ├── special-characters.csv      # Unicode/international data
│   │       ├── empty-sample.csv            # Empty file edge case
│   │       └── README.md                   # Test data documentation
│   └── run-tests.sh           # Main test runner script
├── tmp/                       # Temporary files (gitignored)
└── README.md                  # Main project documentation
```