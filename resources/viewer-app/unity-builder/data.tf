# Data sources for unity-builder module

# Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get ECS cluster from remote state
data "terraform_remote_state" "viewer_app_ecs_cluster" {
  backend = "s3"
  config = {
    bucket = "barts-terraform-state-1750103475"
    key    = "infrastructure/viewer-app/ecs-cluster/terraform.tfstate"
    region = var.aws_region
  }
  workspace = terraform.workspace
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get the ECS cluster
data "aws_ecs_cluster" "main" {
  cluster_name = data.terraform_remote_state.viewer_app_ecs_cluster.outputs.cluster_id
}
