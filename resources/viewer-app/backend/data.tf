# Get default VPC
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
# Remote state data source for viewer-app-database
data "terraform_remote_state" "viewer_app_database" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket = "barts-terraform-state-1750103475"
    key    = "infrastructure/viewer-app/database/terraform.tfstate"
    region = "us-east-1"
  }
}

# Remote state data source for viewer-app-ecs-cluster
data "terraform_remote_state" "viewer_app_ecs_cluster" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket = "barts-terraform-state-1750103475"
    key    = "infrastructure/viewer-app/ecs-cluster/terraform.tfstate"
    region = "us-east-1"
  }
}

# Remote state data source for global-route-53
data "terraform_remote_state" "global_route53" {
  backend   = "s3"
  workspace = "global"
  config = {
    bucket = "barts-terraform-state-1750103475"
    key    = "infrastructure/route-53/terraform.tfstate"
    region = "us-east-1"
  }
}

# Remote state data source for viewer-app-secrets
data "terraform_remote_state" "viewer_app_secrets" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket = "barts-terraform-state-1750103475"
    key    = "infrastructure/viewer-app/secrets/terraform.tfstate"
    region = "us-east-1"
  }
}
