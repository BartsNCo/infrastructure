
# Local values from remote states
locals {
  viewer_app_database_mongodb_connection_secret_arn = data.terraform_remote_state.viewer_app_database.outputs.mongodb_connection_secret_arn
  viewer_app_ecs_cluster_id                         = data.terraform_remote_state.viewer_app_ecs_cluster.outputs.cluster_id
  route53_zone_id                                   = data.terraform_remote_state.global_route53.outputs.hosted_zone_id[terraform.workspace]
}

# S3 Unity module
module "s3unity" {
  source = "../modules/s3unity"

  project_name           = var.project_name
  environment            = terraform.workspace
  allow_direct_s3_access = true
}


module "backend" {
  source = "../modules/ecs-service"

  project_name     = var.project_name
  environment      = terraform.workspace
  application_name = "viewer-backend"
  cluster_id       = local.viewer_app_ecs_cluster_id
  vpc_id           = data.aws_vpc.default.id
  subnet_ids       = data.aws_subnets.default.ids
  route53_zone_id  = local.route53_zone_id
  subdomains       = ["api"]
  certificate_arn  = data.terraform_remote_state.global_route53.outputs.certificate_arn[terraform.workspace]


  container_definitions = {
    name = "backend"
    environment_variables = [
      {
        name  = "NODE_ENV"
        value = "production"
      },
      {
        name  = "PORT"
        value = "3000"
      }
    ]
    secrets = [
      {
        secret_manager_arn = local.viewer_app_database_mongodb_connection_secret_arn
        key                = "MONGODB_URI"
      }
    ]
  }

  s3_bucket_names   = [module.s3unity.bucket_name]
  container_port    = 3000
  cpu               = 1024
  memory            = 2048
  desired_count     = 1
  health_check_path = "/health"
}
