# S3 Unity module
module "s3unity" {
  source = "../modules/s3unity"

  project_name           = var.project_name
  environment            = terraform.workspace
  allow_direct_s3_access = true
}

