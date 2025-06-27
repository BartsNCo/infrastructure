# ECS Cluster - Container Orchestration Platform

This Terraform configuration creates an Amazon ECS (Elastic Container Service) cluster for running containerized applications in the Barts Tours VR platform.

## Overview

The ECS cluster provides:
- Container orchestration for backend and frontend services
- Scalable compute platform for Docker containers
- Integration with AWS monitoring and logging services
- Foundation for service deployment and management

## Resources Created

### Core Infrastructure
- **ECS Cluster**: Named `{project_name}_viewer_cluster_{environment}`
- **Container Insights**: Optional CloudWatch monitoring integration
- **Resource Tagging**: Consistent environment and project tagging

## Configuration

### Cluster Settings

```hcl
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}_viewer_cluster_${terraform.workspace}"
  
  # Optional: Enable detailed monitoring
  dynamic "setting" {
    for_each = var.enable_container_insights ? [1] : []
    content {
      name  = "containerInsights"
      value = "enabled"
    }
  }
}
```

### Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `project_name` | Project identifier | `string` | Required |
| `enable_container_insights` | Enable CloudWatch Container Insights | `bool` | `false` |

## Usage

### Deploy Cluster

```bash
cd infrastructure/viewer-app/ecs-cluster

# Initialize Terraform
terraform init

# Select workspace
terraform workspace select development

# Plan deployment
terraform plan

# Apply changes
terraform apply
```

### Service Integration

Other services reference this cluster via remote state:

```hcl
data "terraform_remote_state" "viewer_app_ecs_cluster" {
  backend = "s3"
  config = {
    bucket    = "barts-terraform-state-1750103475"
    key       = "viewer-app/ecs-cluster/terraform.tfstate"
    region    = "us-east-1"
    workspace = terraform.workspace
  }
}

locals {
  cluster_id = data.terraform_remote_state.viewer_app_ecs_cluster.outputs.cluster_id
}
```

## Service Deployment

### Backend Service Example

The backend service deploys to this cluster:

```hcl
module "backend" {
  source = "../../../modules/ecs-service"
  
  cluster_id = local.viewer_app_ecs_cluster_id
  # ... other configuration
}
```

### Frontend Service Example

The frontend service also uses this cluster:

```hcl
module "frontend" {
  source = "../../../modules/ecs-service"
  
  cluster_id = local.viewer_app_ecs_cluster_id
  # ... other configuration
}
```

## Monitoring and Observability

### Container Insights (Optional)

When enabled, Container Insights provides:
- Container-level CPU and memory utilization
- Network and storage metrics
- Application logs aggregation
- Performance monitoring dashboards

### CloudWatch Integration

- **Service Logs**: Automatic log group creation for services
- **Metrics**: CPU, memory, and network utilization tracking
- **Alarms**: Configurable alerts for service health

## Networking

### VPC Integration

Services deployed to this cluster use:
- Default VPC subnets for task placement
- Security groups for network access control
- Application Load Balancer for traffic distribution

### Service Discovery

- **Route53 Integration**: DNS-based service discovery
- **Load Balancer**: Health checks and traffic routing
- **SSL Termination**: HTTPS support via ACM certificates

## Scaling and Performance

### Capacity Providers

The cluster can be configured with capacity providers for:
- **Fargate**: Serverless container execution
- **EC2**: Traditional instance-based deployment
- **Spot Instances**: Cost-optimized workloads

### Auto Scaling

Services can implement:
- **Target Tracking**: Scale based on CPU/memory utilization
- **Step Scaling**: Multi-threshold scaling policies
- **Scheduled Scaling**: Predictable workload patterns

## Security Features

### IAM Integration
- **Task Roles**: Least-privilege access for containers
- **Execution Roles**: ECS agent permissions
- **Service-Linked Roles**: AWS-managed permissions

### Network Security
- **Security Groups**: Fine-grained network access control
- **VPC Isolation**: Private subnet deployment
- **Secrets Management**: Integration with AWS Secrets Manager

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_id` | ECS cluster identifier |
| `cluster_arn` | ECS cluster ARN |
| `cluster_name` | ECS cluster name |

## Dependent Services

This cluster serves as the foundation for:

1. **[Backend Service](../backend/)** - Node.js API server
2. **[Frontend Service](../frontend/)** - React application
3. **Future Services** - Additional microservices

## Maintenance

### Cluster Updates

```bash
# View cluster status
aws ecs describe-clusters --clusters barts_viewer_cluster_development

# List running services
aws ecs list-services --cluster barts_viewer_cluster_development

# View cluster capacity
aws ecs describe-capacity-providers --cluster barts_viewer_cluster_development
```

### Container Insights Management

```bash
# Enable Container Insights
aws ecs put-account-setting --name "containerInsights" --value "enabled"

# View insights data
aws logs describe-log-groups --log-group-name-prefix "/aws/ecs/containerinsights"
```

## Cost Optimization

### Development Environment
- **Fargate**: Pay-per-use pricing model
- **Minimal Resources**: Right-sized CPU and memory allocation
- **Auto Scaling**: Scale to zero during off-hours

### Monitoring
- **Container Insights**: Additional CloudWatch charges
- **Log Retention**: Configure appropriate retention periods
- **Metrics**: Monitor CloudWatch usage costs

## Troubleshooting

### Common Issues

1. **Service Won't Start**: Check task definition and resource limits
2. **Network Connectivity**: Verify security groups and subnet routing
3. **Permission Errors**: Review IAM task and execution roles

### Debug Commands

```bash
# Check cluster status
aws ecs describe-clusters --clusters barts_viewer_cluster_development

# View service details
aws ecs describe-services --cluster barts_viewer_cluster_development --services backend

# Check task logs
aws logs get-log-events --log-group-name "/ecs/backend" --log-stream-name "ecs/backend/task-id"
```

## Best Practices

1. **Resource Tagging**: Consistent tagging for cost allocation
2. **Monitoring**: Enable Container Insights for production workloads  
3. **Security**: Use least-privilege IAM roles
4. **Scaling**: Configure appropriate auto-scaling policies
5. **Logging**: Centralize logs in CloudWatch for observability