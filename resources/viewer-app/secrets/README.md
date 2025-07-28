# Secrets - AWS Secrets Manager Configuration

This Terraform configuration manages secure credential storage using AWS Secrets Manager for the Barts Tours VR platform.

## Overview

The secrets configuration provides:
- Centralized secret management for API keys and credentials
- Automated secret rotation capabilities
- IAM-based access control for applications
- GitHub Actions integration for CI/CD workflows

## Resources Created

### Secret Management
- **AWS Secrets Manager Secrets**: JSON-formatted secrets with configurable rotation
- **IAM Policies**: Fine-grained access control for ECS services and GitHub Actions
- **GitHub Repository Secrets**: Automated secret ARN injection for CI/CD pipelines

## Configuration

### Default Secrets Structure

The configuration supports multiple secret types defined in `variables.tf`:

```hcl
variable "secrets" {
  description = "Map of secrets to create"
  type = map(object({
    description      = string
    data            = map(string)
    enable_rotation = bool
    rotation_days   = number
  }))
}
```

### Secret Types

#### API Keys (`api-keys`)
- Application-specific API keys
- Third-party service credentials
- Internal service authentication tokens

#### JWT Secrets (`jwt-secrets`)
- JWT signing secrets
- Token encryption keys
- Session management secrets

#### Google Sign-In (`google-signin`)
- Google OAuth client credentials
- Callback URLs and redirect URIs
- Authentication domain configuration

## Usage

### Deploy Secrets

```bash
cd infrastructure/viewer-app/secrets

# Initialize
terraform init

# Select workspace
terraform workspace select development

# Plan deployment
terraform plan

# Apply changes
terraform apply
```

### Access Patterns

#### ECS Service Integration

Services reference secrets via ARN in their task definitions:

```hcl
secrets = [
  {
    secret_manager_arn = data.terraform_remote_state.viewer_app_secrets.outputs.secret_arns["jwt-secrets"]
    key                = "JWT_SECRET"
  }
]
```

#### GitHub Actions Integration

The configuration automatically sets repository secrets for CI/CD:

```bash
# Automatically executed by Terraform
gh secret set GOOGLE_SIGNIN_SECRET_ARN -e development -b "arn:aws:secretsmanager:..." --repo BartsNCo/Backend
```

## Secret Data Structure

### Google Sign-In Secret Example

```json
{
  "GOOGLE_CLIENT_ID": "your-google-client-id",
  "GOOGLE_CLIENT_SECRET": "your-google-client-secret",
  "GOOGLE_CALLBACK_URL": "https://api.dev.bartsnco.com.br/auth/google/callback",
  "CLIENT_REDIRECT_URL": "https://dev.bartsnco.com.br/auth/success",
  "CLIENT_REDIRECT_FAILURE": "https://dev.bartsnco.com.br/auth/failure",
  "AUTH_DOMAIN": "dev.bartsnco.com.br"
}
```

### JWT Secrets Example

```json
{
  "JWT_SECRET": "your-jwt-signing-secret",
  "JWT_REFRESH_SECRET": "your-jwt-refresh-secret",
  "TOKEN_EXPIRY": "24h"
}
```

## Security Features

### Access Control
- **ReadWrite Groups**: IAM groups with full secret access (`Dev` group)
- **ECS Task Roles**: Least-privilege access for containerized applications
- **GitHub Actions**: Scoped access for CI/CD workflows

### Rotation
- **Configurable Rotation**: Enable automatic rotation per secret
- **Custom Rotation Days**: Set rotation frequency (default: 30 days)
- **Recovery Window**: Configurable recovery period before permanent deletion

### Encryption
- **KMS Integration**: Secrets encrypted with AWS KMS
- **In-Transit**: TLS encryption for all API calls
- **At-Rest**: Encrypted storage in AWS Secrets Manager

## Outputs

| Output | Description |
|--------|-------------|
| `secret_arns` | Map of secret names to their ARNs |
| `secret_names` | Map of secret names to their full resource names |

## Integration with Other Components

### Backend Service

The backend service automatically receives secret ARNs via remote state:

```hcl
data "terraform_remote_state" "viewer_app_secrets" {
  backend = "s3"
  config = {
    bucket    = "barts-terraform-state-1750103475"
    key       = "viewer-app/secrets/terraform.tfstate"
    region    = "us-east-1"
    workspace = terraform.workspace
  }
}
```

### GitHub Actions

Repository secrets are automatically configured for environment-specific deployments:
- `GOOGLE_SIGNIN_SECRET_ARN`: ARN for Google OAuth credentials
- Additional secrets can be added via local-exec provisioners

## Management Commands

### Manual Secret Updates

```bash
# Update secret value
aws secretsmanager update-secret \
  --secret-id barts-google-signin-development \
  --secret-string '{"GOOGLE_CLIENT_ID":"new-value"}'

# Force rotation
aws secretsmanager rotate-secret \
  --secret-id barts-google-signin-development
```

### Retrieve Secret Values

```bash
# Get secret value
aws secretsmanager get-secret-value \
  --secret-id barts-google-signin-development \
  --query SecretString --output text | jq
```

## Best Practices

### Secret Management
1. **Never commit secrets to version control**
2. **Use environment-specific secret names**
3. **Enable rotation for sensitive credentials**
4. **Monitor secret access via CloudTrail**

### Development Workflow
1. **Create secrets manually in AWS Console first**
2. **Import existing secrets into Terraform state**
3. **Update secret values through AWS Console or CLI**
4. **Use Terraform only for infrastructure management**

## Troubleshooting

### Common Issues

1. **GitHub CLI Not Available**: Ensure `gh` CLI is installed and authenticated
2. **Permission Denied**: Check IAM roles have SecretsManager permissions
3. **Secret Not Found**: Verify secret exists before referencing in other components

### Debug Commands

```bash
# Check secret exists
aws secretsmanager describe-secret --secret-id barts-google-signin-development

# List all secrets
aws secretsmanager list-secrets --query 'SecretList[?contains(Name, `barts`)].Name'

# Test GitHub CLI access
gh auth status
gh secret list --repo BartsNCo/Backend
```

## Cost Considerations

- **Storage**: $0.40 per secret per month
- **API Calls**: $0.05 per 10,000 requests  
- **Rotation**: Additional costs for Lambda-based rotation
- **Development Environment**: Estimated $5-10/month for typical secret usage