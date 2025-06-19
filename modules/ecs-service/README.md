# ECS Service Module

## Description

This module creates a complete ECS Fargate service with:
- ECR repository for container images
- ECS task definition with single container
- ECS service running on Fargate
- Application Load Balancer for web access
- Security groups for proper networking
- CloudWatch logs for monitoring
- IAM roles with necessary permissions

## Usage

```hcl
module "backend_service" {
  source = "./modules/ecs-service"

  project_name     = "barts"
  environment      = "development"
  application_name = "backend"
  cluster_id       = aws_ecs_cluster.main.id
  vpc_id           = data.aws_vpc.default.id
  subnet_ids       = data.aws_subnets.default.ids

  container_definitions = {
    name = "backend"
    environment_variables = [
      {
        name  = "NODE_ENV"
        value = "production"
      },
      {
        name  = "PORT"
        value = "3000"
      }
    ]
    secrets = [
      {
        secret_manager_arn = aws_secretsmanager_secret.db_password.arn
        key               = "DB_PASSWORD"
      }
    ]
  }

  docker_image      = "my-app:latest"
  container_port    = 3000
  cpu              = 512
  memory           = 1024
  desired_count    = 2
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name prefix for resources | `string` | n/a | yes |
| environment | Environment name | `string` | n/a | yes |
| application_name | Application name for the service | `string` | n/a | yes |
| cluster_id | ECS cluster ID where the service will run | `string` | n/a | yes |
| vpc_id | VPC ID for networking resources | `string` | n/a | yes |
| subnet_ids | List of subnet IDs for the service | `list(string)` | n/a | yes |
| container_definitions | Container definitions configuration | `object` | n/a | yes |
| docker_image | Docker image to use for the container | `string` | `"public.ecr.aws/docker/library/busybox:latest"` | no |
| container_port | Port that the container listens on | `number` | `80` | no |
| cpu | CPU units for the task (256, 512, 1024, etc.) | `number` | `256` | no |
| memory | Memory in MiB for the task | `number` | `512` | no |
| desired_count | Desired number of tasks | `number` | `1` | no |
| health_check_path | Health check path for the load balancer | `string` | `"/health"` | no |
| tags | Common tags to apply to all resources | `map(string)` | `{}` | no |

## Container Definitions Object

The `container_definitions` variable expects an object with the following structure:

```hcl
{
  name = "container-name"
  environment_variables = [
    {
      name  = "VARIABLE_NAME"
      value = "variable_value"
    }
  ]
  secrets = [
    {
      secret_manager_arn = "arn:aws:secretsmanager:region:account:secret:name"
      key               = "SECRET_KEY"
    }
  ]
}
```

## Outputs

| Name | Description |
|------|-------------|
| service_dns | The DNS name of the load balancer |
| service_url | The full URL of the service |
| ecr_repository_uri | The private URI of the ECR repository |
| ecr_repository_name | The name of the ECR repository |
| ecs_service_name | The name of the ECS service |
| ecs_task_definition_arn | The ARN of the ECS task definition |
| load_balancer_arn | The ARN of the load balancer |
| load_balancer_zone_id | The zone ID of the load balancer |
| target_group_arn | The ARN of the target group |
| ecs_security_group_id | The ID of the ECS service security group |
| alb_security_group_id | The ID of the ALB security group |
| log_group_name | The name of the CloudWatch log group |

## Features

- **Fargate Launch Type**: Serverless container execution
- **Auto-scaling Ready**: Easily configurable desired count
- **Web Accessible**: Application Load Balancer with public access
- **Secure**: Security groups with minimal required access
- **Monitoring**: CloudWatch logs with 7-day retention
- **ECR Integration**: Dedicated repository for each service
- **Secrets Management**: AWS Secrets Manager integration
- **Health Checks**: Configurable health check endpoint
- **Default Image**: Uses busybox with tail command if no image specified