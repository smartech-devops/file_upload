## Repository Structure

```
file_upload/
├── bootstrap/
│   ├── main.tf                 # OIDC provider and GitHub Actions role
│   ├── variables.tf            # Bootstrap variables
│   └── outputs.tf              # Role ARN output
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions workflow
├── lambda/
│   ├── lambda_function.py      # Lambda source code
│   └── requirements.txt        # Python dependencies
├── terraform/
│   ├── main.tf                 # Infrastructure definitions
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   └── terraform.tfvars        # Variable values
└── README.md                   # Documentation
```