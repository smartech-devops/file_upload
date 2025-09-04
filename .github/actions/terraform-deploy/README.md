# Terraform Deploy Action

A flexible composite GitHub Action for Terraform deployments with support for plan-only, apply-only, or combined plan-apply workflows.

## Description

This action provides a comprehensive Terraform deployment workflow with multiple execution modes. It handles initialization, validation, planning, and applying of Terraform configurations with proper error handling and artifact management.

## Features

- **🎯 Flexible Modes**: Plan-only, apply-only, or combined plan-apply
- **📋 Rich Outputs**: Plan status, change detection, Terraform outputs
- **🛡️ Safety**: Proper validation and error handling
- **📊 Artifacts**: Automatic upload of plan files and state info
- **🔍 Visibility**: Detailed logging and status reporting

## Usage

### Plan Only Mode
Perfect for pull requests to validate changes without applying them:

```yaml
- name: Plan Infrastructure Changes
  uses: ./.github/actions/terraform-deploy
  with:
    action: 'plan'
    show-plan: 'true'
```

### Apply Only Mode
Use when you have a pre-generated plan file:

```yaml
- name: Apply Infrastructure Changes
  uses: ./.github/actions/terraform-deploy
  with:
    action: 'apply'
    plan-file: 'tfplan'
```

### Combined Plan-Apply Mode (Default)
Full deployment workflow - plan then apply:

```yaml
- name: Deploy Infrastructure
  uses: ./.github/actions/terraform-deploy
  with:
    action: 'plan-apply'
    auto-approve: 'true'
```

### Advanced Usage with Conditional Apply

```yaml
- name: Plan Infrastructure
  id: plan
  uses: ./.github/actions/terraform-deploy
  with:
    action: 'plan'
    show-plan: 'true'

- name: Apply Changes
  if: steps.plan.outputs.has-changes == 'true'
  uses: ./.github/actions/terraform-deploy
  with:
    action: 'apply'
    plan-file: 'tfplan'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `action` | Terraform action to perform (`plan`, `apply`, `plan-apply`) | No | `plan-apply` |
| `terraform-directory` | Directory containing Terraform configuration | No | `terraform` |
| `auto-approve` | Auto-approve apply without confirmation | No | `true` |
| `show-plan` | Display plan output in logs | No | `true` |
| `plan-file` | Name of the plan file to create/use | No | `tfplan` |

## Outputs

| Output | Description |
|--------|-------------|
| `plan-exitcode` | Exit code from terraform plan (0=no changes, 1=error, 2=changes) |
| `apply-exitcode` | Exit code from terraform apply (if executed) |
| `terraform-outputs` | Terraform outputs in JSON format |
| `plan-file-path` | Full path to the generated plan file |
| `has-changes` | Whether the plan contains changes (`true`/`false`) |

## Action Modes

### 1. Plan Mode (`action: 'plan'`)

**Steps executed:**
1. ✅ Setup Terraform
2. ✅ Terraform Init
3. ✅ Terraform Validate
4. ✅ Terraform Plan
5. ✅ Show Plan (if enabled)
6. ✅ Upload Plan File as Artifact

**Use cases:**
- Pull request validation
- Change review process
- CI/CD pipeline gates

### 2. Apply Mode (`action: 'apply'`)

**Steps executed:**
1. ✅ Setup Terraform
2. ✅ Terraform Init
3. ✅ Check Plan File Exists
4. ✅ Terraform Apply
5. ✅ Get Terraform Outputs

**Use cases:**
- Applying pre-approved plans
- Separate plan/apply workflows
- Manual approval processes

### 3. Plan-Apply Mode (`action: 'plan-apply'`)

**Steps executed:**
1. ✅ Setup Terraform
2. ✅ Terraform Init
3. ✅ Terraform Validate
4. ✅ Terraform Plan
5. ✅ Show Plan (if enabled)
6. ✅ Terraform Apply (if changes detected)
7. ✅ Get Terraform Outputs

**Use cases:**
- Complete deployment workflows
- Development/staging environments
- Automated deployments

## Exit Codes

### Plan Exit Codes
- `0`: No changes needed
- `1`: Error occurred
- `2`: Changes detected

### Apply Exit Codes
- `0`: Successfully applied
- `1`: Error occurred

## Artifacts

The action automatically uploads artifacts for debugging and auditing:

### Plan Artifacts
- **Name**: `terraform-plan-{run-id}`
- **Contents**: Generated plan file
- **When**: Plan mode only

### State Info Artifacts
- **Name**: `terraform-state-info-{run-id}`
- **Contents**: Terraform outputs (JSON), plan file
- **When**: Always (if files exist)
- **Retention**: 30 days

## Error Handling

The action includes comprehensive error handling:

- **Input Validation**: Validates action type and directory existence
- **Terraform Validation**: Checks configuration syntax
- **Plan Validation**: Handles all plan exit codes appropriately
- **Apply Safety**: Ensures plan file exists for apply-only mode
- **Graceful Failures**: Proper exit codes and error messages

## Workflow Integration Examples

### Basic Deployment Workflow

```yaml
name: Deploy Infrastructure
on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: eu-north-1
      
      - name: Deploy Infrastructure
        uses: ./.github/actions/terraform-deploy
        with:
          action: 'plan-apply'
```

### PR Validation Workflow

```yaml
name: Validate Infrastructure
on:
  pull_request:
    branches: [ main ]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: eu-north-1
      
      - name: Plan Infrastructure Changes
        uses: ./.github/actions/terraform-deploy
        with:
          action: 'plan'
          show-plan: 'true'
```

### Separate Plan/Apply Workflow

```yaml
name: Infrastructure Deployment
on:
  workflow_dispatch:
    inputs:
      action:
        description: 'Action to perform'
        required: true
        default: 'plan'
        type: choice
        options:
        - plan
        - apply

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: eu-north-1
      
      - name: Download Plan File
        if: github.event.inputs.action == 'apply'
        uses: actions/download-artifact@v4
        with:
          name: terraform-plan-latest
          path: terraform/
      
      - name: Execute Terraform
        uses: ./.github/actions/terraform-deploy
        with:
          action: ${{ github.event.inputs.action }}
```

## Prerequisites

- **AWS Credentials**: Must be configured before using this action
- **Terraform Backend**: Backend configuration should be properly set up
- **Permissions**: Appropriate AWS permissions for Terraform operations
- **Directory Structure**: Terraform files must exist in specified directory

## Troubleshooting

### Common Issues

1. **"Terraform directory not found"**
   - Verify the `terraform-directory` input points to correct location
   - Ensure Terraform files exist in the specified directory

2. **"Plan file not found" (apply mode)**
   - Run plan action first to generate plan file
   - Verify plan file name matches between plan and apply steps

3. **"Terraform initialization failed"**
   - Check backend configuration
   - Verify AWS credentials and permissions
   - Ensure required providers are accessible

4. **"Configuration validation failed"**
   - Review Terraform syntax errors in logs
   - Check for missing required variables
   - Validate provider configurations

### Debug Mode

Enable detailed logging by setting show-plan to true:

```yaml
- uses: ./.github/actions/terraform-deploy
  with:
    show-plan: 'true'
```

## Contributing

When modifying this action:

1. Test all three modes (plan, apply, plan-apply)
2. Verify error handling scenarios  
3. Check artifact uploads work correctly
4. Update documentation for any new inputs/outputs
5. Validate with different Terraform configurations