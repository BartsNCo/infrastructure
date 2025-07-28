# Frontend - React Application Service

This Terraform configuration deploys the React frontend application for the Barts Tours VR platform using Amazon ECS (Elastic Container Service).

## Overview

The frontend service provides:
- React/TypeScript application with Vite build system
- Containerized deployment on ECS Fargate
- Custom domain with SSL/TLS termination
- Load balancer with health checks
- Production-optimized container configuration

## Resources Created

### ECS Service Infrastructure
- **ECS Service**: Managed container service on Fargate
- **Task Definition**: Container specifications and resource allocation
- **Application Load Balancer**: Traffic distribution and SSL termination
- **Target Groups**: Health check and routing configuration
- **Security Groups**: Network access control

### DNS and SSL
- **Route53 Records**: Root domain configuration (`dev.bartsnco.com.br`)
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
| **Health Check** | `/api/health` | Health check endpoint |

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
  }
]
```

### Domain Configuration
- **Subdomain**: Root domain (empty string in `subdomains = [""]`)
- **Full Domain**: `dev.bartsnco.com.br`
- **SSL**: ACM-managed certificate with auto-renewal

## Dependencies

The frontend service depends on several infrastructure components:

### Required Remote States

1. **ECS Cluster**: Container orchestration platform
2. **Route53**: DNS zone and SSL certificates

### Data Sources

```hcl
data "terraform_remote_state" "viewer_app_ecs_cluster" {
  # ECS cluster configuration
}

data "terraform_remote_state" "global_route53" {
  # DNS zone and certificate ARNs
}
```

## Usage

### Deploy Frontend Service

```bash
cd infrastructure/viewer-app/frontend

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
2. Route53 (shared configuration)

## Application Architecture

### React + Vite Stack
- **Frontend Framework**: React with TypeScript
- **Build Tool**: Vite for fast development and optimized production builds
- **Container Runtime**: Node.js serving production build
- **HTTP Server**: Typically Express.js or similar serving static assets

### Container Build Process
```dockerfile
# Typical Dockerfile structure
FROM node:alpine as builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

FROM node:alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
EXPOSE 3000
CMD ["npm", "start"]
```

## Networking

### Domain Configuration
- **Primary Domain**: `dev.bartsnco.com.br`
- **SSL Certificate**: ACM-managed certificate with auto-renewal
- **Protocol**: HTTPS only (HTTP redirects to HTTPS)

### Load Balancer
- **Type**: Application Load Balancer (ALB)
- **Scheme**: Internet-facing
- **Target Type**: IP (for Fargate tasks)
- **Health Check**: HTTP GET /api/health

### Security Groups
- **Inbound**: Port 3000 from ALB only
- **Outbound**: HTTPS (443) for external API calls

## Integration with Backend

The frontend communicates with the backend service:

### API Configuration
- **Backend URL**: `https://api.dev.bartsnco.com.br`
- **Authentication**: JWT tokens and Google OAuth
- **CORS**: Configured on backend for frontend domain

### Environment Variables (Build-time)
```bash
# Set during CI/CD build process
VITE_API_URL=https://api.dev.bartsnco.com.br
VITE_ENVIRONMENT=development
```

## Monitoring and Logging

### CloudWatch Integration
- **Application Logs**: Centralized logging in CloudWatch
- **Metrics**: CPU, memory, and request metrics
- **Alarms**: Automated alerts for service health

### Health Monitoring
- **Load Balancer Health Checks**: Every 30 seconds
- **ECS Service Health**: Task replacement on failure
- **Application Health**: Custom health endpoint monitoring

### Log Groups
- **Application Logs**: `/aws/ecs/frontend`
- **Access Logs**: Load balancer access patterns
- **Error Logs**: Application errors and exceptions

## Performance Optimization

### Static Asset Optimization
- **Vite Build**: Optimized bundle sizes with tree shaking
- **Compression**: Gzip/Brotli compression at load balancer
- **Caching**: Browser caching headers for static assets
- **CDN**: Consider CloudFront integration for global distribution

### Container Optimization
- **Multi-stage Build**: Minimize final image size
- **Node.js Configuration**: Production mode optimizations
- **Memory Management**: Proper heap size configuration

## Security Features

### IAM Roles
- **Task Role**: Minimal permissions for application functionality
- **Execution Role**: ECS task execution permissions
- **Least Privilege**: No unnecessary AWS service access

### Network Security
- **VPC Isolation**: Tasks run in private subnets
- **Security Groups**: Restricted to ALB traffic only
- **SSL/TLS**: End-to-end encryption for all traffic

### Content Security
- **HTTPS Only**: Secure transmission of all content
- **CSP Headers**: Content Security Policy headers
- **CORS**: Proper Cross-Origin Resource Sharing configuration

## Scaling Configuration

### Auto Scaling (Optional)
```hcl
# Can be added for production workloads
autoscaling_min_capacity = 1
autoscaling_max_capacity = 5
target_cpu_utilization = 70
```

### Manual Scaling
```bash
# Update desired count
terraform apply -var="desired_count=2"
```

## Deployment Pipeline

### CI/CD Integration
The frontend service integrates with GitHub Actions:

1. **Build**: React application build with Vite
2. **Environment Variables**: Inject build-time configuration
3. **Docker Build**: Create optimized container image
4. **Push**: Image pushed to ECR registry
5. **Deploy**: ECS service update with new image
6. **Health Check**: Verify deployment success

### Build Environment Variables
```yaml
# GitHub Actions workflow
env:
  VITE_API_URL: https://api.dev.bartsnco.com.br
  VITE_GOOGLE_CLIENT_ID: ${{ secrets.GOOGLE_CLIENT_ID }}
```

## Development Workflow

### Local Development
```bash
# Frontend development
cd BartsViewer-Frontend/Barts-Tour-Suite/client
yarn dev

# Build for production
yarn build

# Preview production build
yarn preview
```

### Environment-specific Configuration
- **Development**: `dev.bartsnco.com.br`
- **Staging**: `staging.bartsnco.com.br` (when configured)
- **Production**: `bartsnco.com.br` (when configured)

## Troubleshooting

### Common Issues

1. **Service Won't Start**: Check task logs in CloudWatch
2. **Health Check Failures**: Verify `/api/health` endpoint exists
3. **DNS Resolution**: Check Route53 record configuration
4. **SSL Certificate**: Verify ACM certificate validation

### Debug Commands

```bash
# Check service status
aws ecs describe-services --cluster barts_viewer_cluster_development --services frontend

# View task logs
aws logs tail /ecs/frontend --follow

# Test health endpoint
curl -k https://dev.bartsnco.com.br/api/health

# Check DNS resolution
nslookup dev.bartsnco.com.br
```

### Common Error Patterns
- **504 Gateway Timeout**: Health check endpoint not responding
- **502 Bad Gateway**: Container not binding to correct port
- **SSL Certificate Issues**: Certificate not validated or expired

## Cost Optimization

### Fargate Pricing (us-east-1)
- **CPU**: $0.04048 per vCPU per hour
- **Memory**: $0.004445 per GB per hour
- **Development**: ~$35/month for 1 task running 24/7

### Cost Reduction Strategies
- **Scheduled Scaling**: Scale to zero during off-hours
- **Resource Right-sizing**: Monitor and adjust CPU/memory
- **CDN Integration**: Reduce load balancer traffic costs

## Static Asset Serving Alternative

### CloudFront + S3 Alternative
For better performance and cost optimization, consider:

```hcl
# Alternative: Static hosting with S3 + CloudFront
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-${terraform.workspace}"
}

resource "aws_cloudfront_distribution" "frontend" {
  # Static asset distribution
  # Better performance for SPA applications
  # Lower costs than ECS for static content
}
```

## Best Practices

1. **Health Checks**: Implement proper health endpoints
2. **Error Boundaries**: React error boundaries for graceful failure handling
3. **Monitoring**: Set up CloudWatch alarms for key metrics
4. **Security Headers**: Implement security headers in responses
5. **Performance**: Monitor Core Web Vitals and user experience metrics
6. **Caching**: Implement proper caching strategies for static assets

## Future Enhancements

### Potential Improvements
- **CDN Integration**: CloudFront for global content delivery
- **Static Hosting**: Migration to S3 + CloudFront for cost efficiency
- **Monitoring**: Real User Monitoring (RUM) integration
- **Analytics**: User behavior tracking and performance monitoring
- **PWA Features**: Progressive Web App capabilities for offline functionality