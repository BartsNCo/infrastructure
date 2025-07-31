data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_route_tables" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "terraform_remote_state" "viewer_app_database" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket = "barts-terraform-state-1750103475"
    key    = "infrastructure/viewer-app/database/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "route53" {
  backend   = "s3"
  workspace = "global"
  config = {
    bucket = "barts-terraform-state-1750103475"
    key    = "infrastructure/route-53/terraform.tfstate"
    region = "us-east-1"
  }
}
