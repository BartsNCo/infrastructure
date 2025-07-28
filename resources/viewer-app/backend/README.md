# Backend - Node.js API Service

This Terraform configuration deploys the Node.js backend API service for the Barts Tours VR platform using Amazon ECS (Elastic Container Service).

## Overview

The backend service provides:
- RESTful API server built with Node.js/Express
- Containerized deployment on ECS Fargate
- Integration with DocumentDB (MongoDB) database
- Secure secrets management for API keys and credentials
- Load balancer with SSL termination
- Custom domain with Route53 DNS

## Resources Created

### ECS Service Infrastructure
- **ECS Service**: Managed container service on Fargate
- **Task Definition**: Container specifications and resource allocation
- **Application Load Balancer**: Traffic distribution and SSL termination
- **Target Groups**: Health check and routing configuration
- **Security Groups**: Network access control

### DNS and SSL
- **Route53 Records**: Custom subdomain configuration (`api.dev.bartsnco.com.br`)
- **ACM Certificate**: SSL/TLS certificate for HTTPS
- **Load Balancer Listeners**: HTTP to HTTPS redirect

## Service Configuration

### Container Specifications

| Setting | Value | Description |
|---------|-------|-------------|
| **CPU** | 1024 | 1 vCPU |
| **Memory** | 2048 MB | 2 GB RAM |
| **Desired Count** | 1 | Number of running tasks |
| **Port** | 3000 | Application port |
| **Health Check** | `/health` | Health check endpoint |

### Environment Variables

```hcl
environment_variables = [
  {
    name  = "NODE_ENV"
    value = "production"
  },
  {
    name  = "PORT"
    value = "3000"
  },
  {
    name  = "AWS_REGION"
    value = var.aws_region
  },
  {
    name  = "S3_BUCKET_NAME"
    value = module.s3unity.bucket_name
  }
]
```

### Secrets Integration

Sensitive data is managed through AWS Secrets Manager:

```hcl
secrets = [
  {
    secret_manager_arn = local.viewer_app_database_mongodb_connection_secret_arn
    key                = "MONGODB_URI"
  },
  {
    secret_manager_arn = local.jwt_secrets_arn
    key                = "JWT_SECRET"
  },
  {
    secret_manager_arn = local.google_signin_secret_arn
    key                = "GOOGLE_CLIENT_ID"
  }
  # ... additional Google OAuth secrets
]
```

## Dependencies

The backend service depends on several other infrastructure components:

### Required Remote States

1. **ECS Cluster**: Container orchestration platform
2. **Database**: DocumentDB connection details
3. **Secrets**: API keys and credentials
4. **Route53**: DNS zone and SSL certificates
5. **Unity Assets**: S3 bucket for file storage

### Data Sources

```hcl
data "terraform_remote_state" "viewer_app_ecs_cluster" {
  # ECS cluster configuration
}

data "terraform_remote_state" "viewer_app_database" {
  # Database connection details
}

data "terraform_remote_state" "viewer_app_secrets" {
  # Secret ARNs for application credentials
}

data "terraform_remote_state" "global_route53" {
  # DNS zone and certificate ARNs
}
```

## Usage

### Deploy Backend Service

```bash
cd infrastructure/viewer-app/backend

# Initialize Terraform
terraform init

# Select workspace
terraform workspace select development

# Plan deployment
terraform plan

# Apply changes
terraform apply
```

### Prerequisites

Ensure these components are deployed first:
1. ECS Cluster (`../ecs-cluster/`)
2. Database (`../database/`)
3. Secrets (`../secrets/`)
4. Route53 (shared configuration)

## API Endpoints

### Health Check
- **URL**: `https://api.dev.bartsnco.com.br/health`
- **Method**: GET
- **Response**: Service status and dependencies

### Authentication
- **Google OAuth**: `/auth/google/*`
- **JWT Tokens**: `/auth/token/*`
- **User Management**: `/auth/user/*`

### Tours and Panoramas
- **Tours**: `/api/tours/*`
- **Panoramas**: `/api/panoramas/*`
- **File Upload**: `/api/upload/*`

## Networking

### Domain Configuration
- **Primary Domain**: `api.dev.bartsnco.com.br`
- **SSL Certificate**: ACM-managed certificate with auto-renewal
- **Protocol**: HTTPS only (HTTP redirects to HTTPS)

### Load Balancer
- **Type**: Application Load Balancer (ALB)
- **Scheme**: Internet-facing
- **Target Type**: IP (for Fargate tasks)
- **Health Check**: HTTP GET /health

### Security Groups
- **Inbound**: Port 3000 from ALB only
- **Outbound**: HTTPS (443) and MongoDB (27017) to required services

## Integration with S3 Unity

The backend service has access to the Unity WebGL S3 bucket:

```hcl
s3_bucket_names = [
  module.s3unity.bucket_name,  # Unity WebGL assets
  "bartsnco-main"              # Additional storage bucket
]
```

### S3 Permissions
- **GetObject**: Read uploaded files
- **PutObject**: Upload new content
- **DeleteObject**: Remove outdated files
- **ListBucket**: Browse bucket contents

## Monitoring and Logging

### CloudWatch Integration
- **Application Logs**: Centralized logging in CloudWatch
- **Metrics**: CPU, memory, and request metrics
- **Alarms**: Automated alerts for service health

### Health Monitoring
- **Load Balancer Health Checks**: Every 30 seconds
- **ECS Service Health**: Task replacement on failure
- **Application Health**: Custom health endpoint monitoring

## Scaling Configuration

### Auto Scaling (Optional)
```hcl
# Can be added for production workloads
autoscaling_min_capacity = 1
autoscaling_max_capacity = 10
target_cpu_utilization = 70
```

### Manual Scaling
```bash
# Update desired count
terraform apply -var="desired_count=3"
```

## Security Features

### IAM Roles
- **Task Role**: Application-level permissions for S3 and Secrets Manager
- **Execution Role**: ECS task execution permissions
- **Least Privilege**: Minimal required permissions only

### Network Security
- **VPC Isolation**: Tasks run in private subnets
- **Security Groups**: Fine-grained network access control
- **SSL/TLS**: End-to-end encryption for all traffic

### Secrets Management
- **No Hardcoded Secrets**: All sensitive data in Secrets Manager
- **Automatic Injection**: Secrets loaded as environment variables
- **Rotation Support**: Compatible with automatic secret rotation

## Deployment Pipeline

### CI/CD Integration
The backend service integrates with GitHub Actions for automated deployment:

1. **Build**: Docker image creation
2. **Push**: Image pushed to ECR registry
3. **Deploy**: ECS service update with new image
4. **Health Check**: Verify deployment success

### Environment Variables in CI/CD
Required GitHub secrets (automatically configured):
- `GOOGLE_SIGNIN_SECRET_ARN`: For OAuth configuration
- Additional secrets as needed for deployment

## Troubleshooting

### Common Issues

1. **Service Won't Start**: Check task logs in CloudWatch
2. **Database Connection**: Verify security groups and connection string
3. **Secret Access**: Ensure IAM roles have Secrets Manager permissions
4. **Load Balancer Errors**: Check target group health

### Debug Commands

```bash
# Check service status
aws ecs describe-services --cluster barts_viewer_cluster_development --services backend

# View task logs
aws logs tail /ecs/backend --follow

# Test health endpoint
curl -k https://api.dev.bartsnco.com.br/health

# Check secret access
aws secretsmanager get-secret-value --secret-id barts-mongodb-connection-development
```

### Log Locations
- **Application Logs**: `/aws/ecs/backend`
- **Load Balancer Logs**: S3 bucket (if enabled)
- **CloudTrail**: API access logs

## Performance Optimization

### Development Environment
- **Resource Allocation**: 1 vCPU, 2GB RAM (cost-optimized)
- **Single Instance**: No redundancy needed for development
- **Monitoring**: Basic CloudWatch metrics

### Production Considerations
- **Multi-AZ Deployment**: Deploy across multiple availability zones
- **Auto Scaling**: Scale based on CPU/memory utilization
- **Enhanced Monitoring**: Enable Container Insights
- **Load Testing**: Validate performance under load

## Cost Optimization

### Fargate Pricing (us-east-1)
- **CPU**: $0.04048 per vCPU per hour
- **Memory**: $0.004445 per GB per hour
- **Development**: ~$35/month for 1 task running 24/7

### Cost Reduction Strategies
- **Scheduled Scaling**: Scale to zero during off-hours
- **Spot Instances**: Use EC2 capacity providers for non-critical workloads
- **Resource Right-sizing**: Monitor and adjust CPU/memory allocation

## Best Practices

1. **Health Checks**: Implement comprehensive health endpoints
2. **Logging**: Structure logs for easy parsing and searching
3. **Monitoring**: Set up CloudWatch alarms for key metrics
4. **Security**: Regularly rotate secrets and update dependencies
5. **Documentation**: Keep API documentation current with OpenAPI/Swagger