# Viewer App - Environment-Specific Infrastructure

This directory contains the Terraform configurations for deploying the Barts Tours VR viewer application components. Each component is designed to be deployed per environment using Terraform workspaces.

## Architecture Overview

The viewer app infrastructure consists of six interconnected components:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   ECS Cluster   │    │     Secrets      │    │     Route53     │
│  (Container     │    │   (API Keys &    │    │   (Shared DNS   │
│  Orchestration) │    │   Credentials)   │    │  & SSL Certs)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│     Backend     │◄───┤     Database     │    │    Frontend     │
│  (API Service   │    │   (DocumentDB    │    │   (Static Web   │
│   on ECS)       │    │    MongoDB)      │    │     Assets)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                                              │
         │              ┌──────────────────┐            │
         └──────────────►│  Unity Assets   │◄───────────┘
                        │  (S3 + CDN for   │
                        │  WebGL Content)  │
                        └──────────────────┘
```

## Components

### Core Infrastructure
1. **[secrets/](./secrets/)** - AWS Secrets Manager for secure credential storage
2. **[ecs-cluster/](./ecs-cluster/)** - ECS cluster for container orchestration
3. **[database/](./database/)** - DocumentDB (MongoDB-compatible) cluster

### Application Services
4. **[backend/](./backend/)** - Node.js API service deployed on ECS
5. **[frontend/](./frontend/)** - React application deployment (if applicable)
6. **[unity-assets/](./unity-assets/)** - S3 bucket with CloudFront for Unity WebGL content

## Environment Workflow

### Terraform Workspaces

Each environment is managed using Terraform workspaces:

```bash
# View current workspace
terraform workspace show

# List all workspaces
terraform workspace list

# Switch to development (current active environment)
terraform workspace select development

# Create new environment
terraform workspace new staging
```

### Deployment Order

Components have dependencies and should be deployed in this order:

1. **Secrets** - Create secret placeholders for API keys and credentials
2. **ECS Cluster** - Set up container orchestration platform
3. **Database** - Deploy DocumentDB cluster
4. **Unity Assets** - Create S3 bucket and CloudFront distribution
5. **Backend** - Deploy API service (depends on all above)
6. **Frontend** - Deploy frontend application (if applicable)

### Deployment Commands

For each component directory:

```bash
cd infrastructure/viewer-app/{component}/

# Initialize Terraform
terraform init

# Select environment workspace
terraform workspace select development

# Plan deployment
terraform plan

# Apply changes
terraform apply

# View outputs
terraform output
```

## Environment Configuration

### Current Environments

- **development**: Active deployment environment
  - Workspace: `development`
  - Resources tagged with `Environment = development`

### Adding New Environments

1. Create new Terraform workspace:
   ```bash
   terraform workspace new {environment-name}
   ```

2. Update shared Route53 configuration to include new subdomain

3. Deploy components in dependency order

4. Update application configurations with new environment URLs

## Inter-Component Communication

Components communicate through Terraform remote state:

```hcl
# Example: Backend reading database connection details
data "terraform_remote_state" "viewer_app_database" {
  backend = "s3"
  config = {
    bucket    = "barts-terraform-state-1750103475"
    key       = "viewer-app/database/terraform.tfstate"
    region    = "us-east-1"
    workspace = terraform.workspace
  }
}

locals {
  mongodb_connection_secret_arn = data.terraform_remote_state.viewer_app_database.outputs.mongodb_connection_secret_arn
}
```

## Environment Variables

Required for all deployments (set in `.envrc`):

```bash
export AWS_PROFILE=barts-admin
export AWS_REGION=us-east-1
export TF_VAR_mongodb_username=bart_root
export TF_VAR_mongodb_password=your_secure_password
```

## Security Features

- **Network Isolation**: Database deployed in VPC with security groups
- **Secret Management**: Sensitive data stored in AWS Secrets Manager
- **SSL/TLS**: HTTPS termination at load balancer level
- **IAM Roles**: Least-privilege access for ECS tasks
- **Tagging**: Consistent resource tagging for environment isolation

## Monitoring and Observability

- CloudWatch logs for all ECS services
- Health check endpoints for service monitoring
- Load balancer health checks
- Database CloudWatch metrics

## Cost Optimization

- **Development Environment**: 
  - ECS tasks with minimal CPU/memory allocation
  - DocumentDB with `db.t3.medium` instances
  - S3 with standard storage class
  - CloudFront with default caching policies

## Troubleshooting

### Common Issues

1. **Remote State Not Found**: Ensure dependency components are deployed first
2. **Workspace Mismatch**: Verify you're in the correct Terraform workspace
3. **Secret Access Denied**: Check IAM roles have proper Secrets Manager permissions
4. **DNS Resolution**: Verify Route53 hosted zone is properly configured

### Debugging Commands

```bash
# Check current workspace and state
terraform workspace show
terraform state list

# View specific resource details
terraform state show {resource_name}

# Check remote state access
terraform refresh
```

## Maintenance

- Monitor certificate expiration in ACM
- Review CloudWatch logs for errors
- Update Docker images for backend services
- Rotate database credentials periodically
- Review and update security groups as needed