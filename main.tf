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
    key     = "terraform.tfstate"
    region  = "us-east-1"
    profile = "barts-admin"
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile"
  type        = string
  default     = "barts-admin"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "barts"
}

variable "mongodb_username" {
  description = "MongoDB master username"
  type        = string
  sensitive   = true
}

variable "mongodb_password" {
  description = "MongoDB master password"
  type        = string
  sensitive   = true
}