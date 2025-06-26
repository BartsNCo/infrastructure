# Database module
module "database" {
  source = "../../../modules/database"

  project_name     = var.project_name
  environment      = terraform.workspace
  mongodb_username = var.mongodb_username
  mongodb_password = var.mongodb_password
  vpc_id           = data.aws_vpc.default.id
  subnet_ids       = data.aws_subnets.default.ids
  instance_class   = "db.t3.medium" # Cheapest available instance class
}

