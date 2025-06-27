# Barts Tours VR Platform - Infrastructure

This repository contains the complete infrastructure-as-code configuration for the Barts Tours VR platform, built with Terraform and deployed on AWS.

## Project Overview

The Barts Tours VR platform is a comprehensive virtual reality touring system consisting of:

- **Frontend**: React/TypeScript application with Vite build system
- **Backend**: Node.js/TypeScript API server with MongoDB integration
- **Unity Assets**: WebGL deployments for VR experiences
- **Infrastructure**: Multi-environment AWS deployment with Terraform

## Repository Structure

```
Infrastructure/
├── infrastructure/
│   ├── route-53/           # Shared DNS and SSL certificate management
│   └── viewer-app/         # Environment-specific application components
│       ├── backend/        # API server deployment
│       ├── database/       # DocumentDB (MongoDB) cluster
│       ├── ecs-cluster/    # ECS cluster for containerized services
│       ├── frontend/       # React application deployment
│       ├── secrets/        # AWS Secrets Manager configuration
│       └── unity-assets/   # S3 and CloudFront for Unity WebGL
└── modules/               # Reusable Terraform modules
```

## Architecture

### Environment Strategy

- **Shared Components** (`infrastructure/route-53/`): DNS zones, SSL certificates, and other resources shared across environments
- **Environment-Specific** (`infrastructure/viewer-app/`): Application components deployed per environment using Terraform workspaces

### Current Deployments

- **Environment**: `development` (Terraform workspace)
- **Domain**: Configured for subdomain-based routing
- **Services**: ECS-based containerized deployment with DocumentDB backend

## Quick Start

### Prerequisites

- AWS CLI configured with `barts-admin` profile
- Terraform >= 1.0
- Required environment variables (see `.envrc`)

### Setup

1. **Load Environment Variables**
   ```bash
   source .envrc
   ```

2. **Initialize Terraform**
   ```bash
   terraform init
   terraform workspace select development
   ```

3. **Deploy Infrastructure**
   ```bash
   # Plan deployment
   terraform plan -var="mongodb_username=bart_root" -var="mongodb_password=YOUR_PASSWORD"
   
   # Apply changes
   terraform apply -var="mongodb_username=bart_root" -var="mongodb_password=YOUR_PASSWORD"
   ```

## Component Overview

### Shared Infrastructure (route-53)
- DNS hosted zones for each environment
- SSL certificates with automatic validation
- Domain management for `*.environment.domain.com` pattern

### Application Infrastructure (viewer-app)
- **ECS Cluster**: Container orchestration platform
- **Backend Service**: Node.js API with secrets management
- **Database**: DocumentDB cluster with VPC security
- **Frontend**: Static asset serving (if applicable)
- **Unity Assets**: S3 bucket with CloudFront CDN
- **Secrets**: Centralized secret management for API keys and credentials

## Environment Management

Each environment is managed through Terraform workspaces:

```bash
# List available environments
terraform workspace list

# Switch to environment
terraform workspace select development

# Create new environment
terraform workspace new staging
```

## Security Features

- VPC-isolated database access
- Secrets Manager integration for sensitive data
- SSL/TLS termination at load balancer
- IAM roles with least-privilege access
- S3 bucket security with optional public access controls

## Monitoring and Maintenance

- CloudWatch logging integration
- Health check endpoints for services
- Automated certificate renewal
- Infrastructure state stored in S3 with versioning

## Development Workflow

1. Make infrastructure changes in appropriate component directory
2. Format code: `terraform fmt`
3. Plan changes: `terraform plan`
4. Apply changes: `terraform apply`
5. Commit changes to version control

## Support

For infrastructure issues or questions, refer to the component-specific README files in each directory or consult the project documentation.