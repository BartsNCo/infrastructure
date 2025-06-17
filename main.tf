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

# App Stack module - Frontend
module "frontend_stack" {
  source = "./modules/app-stack"

  project_name            = var.project_name
  environment             = terraform.workspace
  application_name        = "viewer"
  application_description = "Barts Viewer Application"

  instance_type = "t3.micro"

  environments = {
    "frontend" = {
      description         = "Frontend"
      solution_stack_name = "64bit Amazon Linux 2023 v6.5.2 running Node.js 20"
      tier                = "WebServer"
      settings = [
        {
          namespace = "aws:elasticbeanstalk:application:environment"
          name      = "VITE_API_URL"
          value     = "https://bartsviewer-backend-dev.eba-i2b5m8my.us-east-1.elasticbeanstalk.com"
        }
      ]
    }
  }

  tags = {
    Application = "frontend"
    Tier        = "web"
  }
}
