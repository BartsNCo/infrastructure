# Use the secrets module to create secrets with access policies
module "app_secrets" {
  source   = "../modules/secrets"
  for_each = var.secrets

  secret_name      = "${var.project_name}-${each.key}-${terraform.workspace}"
  description      = each.value.description
  project_name     = var.project_name
  environment      = terraform.workspace
  application_name = var.application_name

  secret_type = "json"
  secret_data = each.value.data

  enable_rotation      = each.value.enable_rotation
  rotation_days        = each.value.rotation_days
  recovery_window_days = var.recovery_window_days

  readwrite_groups = ["Dev"]

  tags = var.additional_tags
}
