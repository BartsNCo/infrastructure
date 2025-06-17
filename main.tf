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
  instance_class   = "db.t4g.medium" # Cheapest available instance class
}

# S3 Unity module
module "s3unity" {
  source = "./modules/s3unity"

  project_name           = var.project_name
  environment            = terraform.workspace
  allow_direct_s3_access = true
}