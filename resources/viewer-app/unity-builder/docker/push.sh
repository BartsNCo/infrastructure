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

# Get current Terraform workspace
cd ..
ENVIRONMENT=$(terraform workspace show)
cd docker

AWS_REGION=${1:-us-east-1}
AWS_PROFILE=${2:-barts-admin}

print_info "Pushing Unity ECS Docker image to ECR"
print_info "Environment (from Terraform workspace): $ENVIRONMENT"
print_info "AWS Region: $AWS_REGION"
print_info "AWS Profile: $AWS_PROFILE"

# Get AWS account ID
print_info "Getting AWS account information..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    print_error "Failed to get AWS account ID. Check your AWS credentials."
    exit 1
fi
print_info "AWS Account ID: $AWS_ACCOUNT_ID"

# ECR repository name based on the Terraform configuration
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

# Read timestamp from tfvars file if it exists
if [ -f ../builder.auto.tfvars ]; then
    TIMESTAMP=$(grep unity_builder_image_tag ../builder.auto.tfvars | cut -d'"' -f2)
    if [ -z "$TIMESTAMP" ]; then
        print_error "Could not read timestamp from ../builder.auto.tfvars"
        print_error "Please run ./build.sh first"
        exit 1
    fi
    print_info "Using timestamp from builder.auto.tfvars: $TIMESTAMP"
else
    print_error "File ../builder.auto.tfvars not found"
    print_error "Please run ./build.sh first"
    exit 1
fi

# Check if the images exist locally
print_info "Checking for local Docker images..."
if ! docker image inspect ${ECR_URI}:latest >/dev/null 2>&1; then
    print_error "Docker image ${ECR_URI}:latest not found locally"
    print_error "Please run ./build.sh first"
    exit 1
fi

if ! docker image inspect ${ECR_URI}:${TIMESTAMP} >/dev/null 2>&1; then
    print_error "Docker image ${ECR_URI}:${TIMESTAMP} not found locally"
    print_error "Please run ./build.sh first"
    exit 1
fi

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

print_info "Push completed successfully!"
print_info ""
print_info "To use this image in your ECS task, update the task definition with:"
print_info "  Image: ${ECR_URI}:latest"
print_info "Full Docker image tag: ${ECR_URI}:${TIMESTAMP}"