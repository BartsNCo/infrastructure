# Remote state data source for global-route-53
data "terraform_remote_state" "global_route53" {
  backend   = "s3"
  workspace = "global"
  config = {
    bucket = "barts-terraform-state-1750103475"
    key    = "global-route-53/terraform.tfstate"
    region = "us-east-1"
  }
}