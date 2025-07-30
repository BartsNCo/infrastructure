#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check required parameters
# if [ $# -lt 1 ]; then
#     print_error "Usage: $0 <environment> [aws-region] [aws-profile] [dockerfile]"
#     print_error "Example: $0 dev us-east-1 default Dockerfile.unity-builder"
#     exit 1
# fi

# Get current Terraform workspace
cd ..
ENVIRONMENT=$(terraform workspace show)
cd docker

AWS_REGION=${1:-us-east-1}
AWS_PROFILE=${2:-barts-admin}
DOCKERFILE=${3:-Dockerfile}

print_info "Building and pushing Unity ECS Docker image"
print_info "Environment (from Terraform workspace): $ENVIRONMENT"
print_info "AWS Region: $AWS_REGION"
print_info "AWS Profile: $AWS_PROFILE"
print_info "Dockerfile: $DOCKERFILE"

# Get AWS account ID
print_info "Getting AWS account information..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    print_error "Failed to get AWS account ID. Check your AWS credentials."
    exit 1
fi
print_info "AWS Account ID: $AWS_ACCOUNT_ID"

# ECR repository name based on the Terraform configuration
#               barts_unity_builder_development
ECR_REPOSITORY="${ENVIRONMENT}-unity-builder"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}"

print_info "ECR Repository: $ECR_REPOSITORY"
print_info "ECR URI: $ECR_URI"

# Login to ECR
print_info "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION --profile $AWS_PROFILE | \
    docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

if [ $? -ne 0 ]; then
    print_error "Failed to login to ECR"
    exit 1
fi
print_info "Successfully logged in to ECR"

# Check if repository exists
# print_info "Checking if ECR repository exists..."
# aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION --profile $AWS_PROFILE >/dev/null 2>&1
# if [ $? -ne 0 ]; then
#     print_error "ECR repository $ECR_REPOSITORY does not exist. Please run Terraform first."
#     exit 1
# fi

# Build the Docker image
print_info "Building Docker image using $DOCKERFILE..."
docker build -f $DOCKERFILE -t ${ECR_REPOSITORY}:latest .
if [ $? -ne 0 ]; then
    print_error "Failed to build Docker image"
    exit 1
fi
print_info "Docker image built successfully"

# Tag the image
print_info "Tagging Docker image..."
docker tag ${ECR_REPOSITORY}:latest ${ECR_URI}:latest

# Also tag with a timestamp for versioning
TIMESTAMP=$(date +%Y%m%d%H%M%S)
docker tag ${ECR_REPOSITORY}:latest ${ECR_URI}:${TIMESTAMP}

# Push the images
print_info "Pushing Docker image to ECR..."
docker push ${ECR_URI}:latest
if [ $? -ne 0 ]; then
    print_error "Failed to push Docker image with latest tag"
    exit 1
fi

docker push ${ECR_URI}:${TIMESTAMP}
if [ $? -ne 0 ]; then
    print_error "Failed to push Docker image with timestamp tag"
    exit 1
fi

print_info "Successfully pushed Docker images to ECR"
print_info "Images pushed:"
print_info "  - ${ECR_URI}:latest"
print_info "  - ${ECR_URI}:${TIMESTAMP}"

# Cleanup local images (optional)
print_warning "Cleaning up local Docker images..."
docker rmi ${ECR_REPOSITORY}:latest || true
docker rmi ${ECR_URI}:latest || true
docker rmi ${ECR_URI}:${TIMESTAMP} || true

print_info "Build and push completed successfully!"
print_info ""
print_info "To use this image in your ECS task, update the task definition with:"
print_info "  Image: ${ECR_URI}:latest"

# Generate the auto.tfvars file
print_info "Generating ../builder.auto.tfvars..."
cat > ../builder.auto.tfvars << EOF
unity_builder_image_tag = "${TIMESTAMP}"
EOF

print_info "Terraform variable file created: ../builder.auto.tfvars"
print_info "Full Docker image tag: ${ECR_URI}:${TIMESTAMP}"
