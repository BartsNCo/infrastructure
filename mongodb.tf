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

# Output the connection details
output "mongodb_endpoint" {
  value = module.database.mongodb_endpoint
}

output "mongodb_port" {
  value = module.database.mongodb_port
}

output "mongodb_connection_string" {
  value     = module.database.mongodb_connection_string
  sensitive = true
}