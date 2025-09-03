# GitHub Repository and Email Configuration

## GitHub Account Details

### Primary Email
`smartech.devops.test@gmail.com`

### Repository Information
- **Username**: `smartech-devops`
- **Repository Name**: `file_upload`
- **Full Repository Path**: `smartech-devops/file_upload`
- **Visibility**: Private (recommended for test projects)
- **Default Branch**: `main`

## Email Configuration for SNS

### SNS Email Subscription
- **Email Address**: `smartech.devops.test@gmail.com`
- **Topic**: Shared SNS topic for both Lambda notifications and CloudWatch alarms
- **Notification Types**:
  - Lambda processing results (success/failure)
  - CloudWatch error alarms (Errors > 0)
  - CloudWatch duration alarms (Duration > 5 seconds)

### Email Confirmation
- SNS will send confirmation email to `smartech.devops.test@gmail.com`
- Must click confirmation link to activate subscription
- Check spam folder if confirmation email not received

## GitHub Actions Configuration

### Repository Secrets
- `AWS_ROLE_ARN` (IAM role for OIDC authentication)

### Repository Variables
- `AWS_REGION`: us-east-1
- `LAMBDA_FUNCTION_NAME`: csv-processor

## OIDC Trust Policy Update

### GitHub Repository Reference
```json
"StringEquals": {
  "token.actions.githubusercontent.com:sub": "repo:smartech-devops/file_upload:ref:refs/heads/main",
  "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
}
```

### Branch Restrictions
- Only `main` branch can assume the role
- Prevents unauthorized deployments from feature branches

## Email Testing Checklist

- [ ] Create GitHub account with `smartech.devops.test@gmail.com`
- [ ] Set up repository `smartech-devops/file_upload`
- [ ] Deploy SNS topic via Terraform
- [ ] Subscribe email to SNS topic
- [ ] Confirm email subscription
- [ ] Test Lambda notification (upload CSV file)
- [ ] Test CloudWatch alarm notification (trigger error)
- [ ] Verify all emails are received in Gmail inbox