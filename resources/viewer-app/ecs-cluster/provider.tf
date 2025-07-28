# Terraform configuration for ECS cluster
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "barts-terraform-state-1750103475"
    key     = "infrastructure/viewer-app/ecs-cluster/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

# Configure the AWS Provider
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = terraform.workspace
    }
  }
}