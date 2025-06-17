terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "barts-terraform-state-1750103475"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Database module
module "database" {
  source = "./modules/database"

  project_name     = var.project_name
  environment      = terraform.workspace
  mongodb_username = var.mongodb_username
  mongodb_password = var.mongodb_password
  vpc_id           = data.aws_vpc.default.id
  subnet_ids       = data.aws_subnets.default.ids
  instance_class   = "db.t3.medium" # Cheapest available instance class
}

# S3 Unity module
module "s3unity" {
  source = "./modules/s3unity"

  project_name           = var.project_name
  environment            = terraform.workspace
  allow_direct_s3_access = true
}

# Existing AWS Elastic Beanstalk Applications (for reference):
# Applications:
# - barts-backend
# - BartsViewer
#
# Environments:
# - BartsViewer-Backend-Dev (Application: barts-backend, Status: Ready, Health: Green)
# - BartsViewer-Frontend-Dev (Application: BartsViewer, Status: Ready, Health: Green)
# - frontend (Application: BartsViewer, Status: Terminated)
#
# Note: These existing resources are not yet managed by Terraform.
# Consider migrating them to use the app-stack module for consistent management.

# Barts VR application stack
module "barts_app_stack" {
  source = "./modules/app-stack"

  project_name            = var.project_name
  environment             = terraform.workspace
  application_name        = "viewer"
  application_description = "Barts Viewer"

  environments = {
    backend = {
      description         = "Backend development environment"
      solution_stack_name = "64bit Amazon Linux 2023 v6.1.8 running Node.js 20"
      tier                = "WebServer"
      instance_type       = "t3.micro"
      settings = [
        {
          namespace = "aws:elasticbeanstalk:application:environment"
          name      = "NODE_ENV"
          value     = "development"
        },
        {
          namespace = "aws:elasticbeanstalk:application:environment"
          name      = "MONGODB_URI"
          value     = module.database.mongodb_connection_string
        }
      ]
    }
    frontend = {
      description         = "Frontend development environment"
      solution_stack_name = "64bit Amazon Linux 2023 v6.1.8 running Node.js 20"
      tier                = "WebServer"
      instance_type       = "t3.micro"
      settings = [
        {
          namespace = "aws:elasticbeanstalk:application:environment"
          name      = "NODE_ENV"
          value     = "production"
        }
      ]
    }
  }
}

