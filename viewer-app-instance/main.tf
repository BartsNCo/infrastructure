
# Local values from viewer-app-database remote state
locals {
  viewer_app_database_mongodb_connection_secret_arn = data.terraform_remote_state.viewer_app_database.outputs.mongodb_connection_secret_arn
}


# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}_viewer_cluster_${terraform.workspace}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Environment = terraform.workspace
    Project     = var.project_name
    Application = "viewer-app"
  }
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
  cluster_id       = aws_ecs_cluster.main.id
  vpc_id           = data.aws_vpc.default.id
  subnet_ids       = data.aws_subnets.default.ids

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

  container_port    = 3000
  cpu               = 1024
  memory            = 2048
  desired_count     = 1
  health_check_path = "/health"

  tags = {
    Environment = terraform.workspace
    Project     = var.project_name
    Application = "viewer-backend"
  }
}
