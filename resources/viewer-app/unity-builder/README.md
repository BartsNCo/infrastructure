# Unity Builder ECS Task

This Terraform module creates an ECS task definition that automatically triggers when new images are uploaded to the `bartsnco-main` S3 bucket.

## Overview

The module sets up:
- An ECS task definition for processing Unity assets
- EventBridge rule to trigger on S3 object creation
- S3 bucket for storing built asset bundles
- IAM roles and policies for task execution
- ECR repository for the container image
- CloudWatch logs for monitoring

## Architecture

When a new file is added to the root of the `bartsnco-main` S3 bucket:
1. S3 sends an event to EventBridge
2. EventBridge triggers the ECS task with the file information
3. The ECS task copies the image to the Unity project structure:
   - Source: `s3://bartsnco-main/<image-uuid>.jpg`
   - Destination: `/app/BartsViewerBundlesBuilder/Assets/panos/<pano-id>/panos/<image-uuid>.jpg`
4. Unity builds asset bundles for all configured platforms
5. Built assets are uploaded to the output S3 bucket:
   - Versioned builds: `s3://<output-bucket>/builds/<timestamp>/<platform>/`
   - Latest builds: `s3://<output-bucket>/latest/<platform>/`

## Container Requirements

The container image should:
1. Have the Unity project at `/app/BartsViewerBundlesBuilder`
2. Read the `S3_OBJECT_KEY` environment variable for the triggered file
3. Parse the pano ID from the image filename or metadata
4. Copy the image to the appropriate directory structure
5. Optionally trigger Unity asset bundle generation

## Usage

```bash
# Initialize Terraform
terraform init -backend-config="bucket=barts-terraform-state-ACCOUNT_ID" \
               -backend-config="key=viewer-app/unity-builder/terraform.tfstate" \
               -backend-config="region=us-east-1"

# Select workspace
terraform workspace select dev

# Plan and apply
terraform plan
terraform apply
```

## Building the Container

Create a Dockerfile for the Unity builder container:

```dockerfile
FROM unityci/editor:ubuntu-6000.0.50f1-linux-il2cpp-3

# Install AWS CLI
RUN apt-get update && apt-get install -y \
    python3-pip \
    && pip3 install awscli \
    && rm -rf /var/lib/apt/lists/*

# Copy Unity project
COPY BartsViewerBundlesBuilder /app/BartsViewerBundlesBuilder

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

WORKDIR /app

ENTRYPOINT ["/app/entrypoint.sh"]
```

Example entrypoint script:

```bash
#!/bin/bash
set -e

# Get the S3 object key from environment
S3_KEY="${S3_OBJECT_KEY}"
S3_BUCKET="${S3_BUCKET:-bartsnco-main}"

# Extract pano ID from the filename (assuming format: <uuid>.jpg)
FILENAME=$(basename "${S3_KEY}")
IMAGE_UUID="${FILENAME%.*}"

# For now, assuming pano ID is passed in metadata or derived from image
# This logic needs to be implemented based on your requirements
PANO_ID="<logic-to-determine-pano-id>"

# Create target directory
TARGET_DIR="/app/BartsViewerBundlesBuilder/Assets/panos/${PANO_ID}/panos"
mkdir -p "${TARGET_DIR}"

# Download the image from S3
aws s3 cp "s3://${S3_BUCKET}/${S3_KEY}" "${TARGET_DIR}/${FILENAME}"

echo "Successfully copied ${S3_KEY} to ${TARGET_DIR}/${FILENAME}"

# Optionally trigger Unity asset bundle build here
# Unity -batchmode -quit -nographics -projectPath /app/BartsViewerBundlesBuilder ...
```

## Outputs

- `task_definition_arn` - ARN of the ECS task definition
- `ecr_repository_url` - URL of the ECR repository
- `eventbridge_rule_name` - Name of the EventBridge rule
- `log_group_name` - CloudWatch log group for task logs
- `output_bucket_name` - Name of the S3 bucket for built assets
- `output_bucket_url` - S3 URL for the output bucket