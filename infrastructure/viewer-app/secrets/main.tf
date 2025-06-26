# Use the secrets module to create secrets with access policies
module "app_secrets" {
  source   = "../../../modules/secrets"
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

# Set GitHub secret for google-signin secret ARN
resource "terraform_data" "github_google_signin_secret" {
  count = contains(keys(var.secrets), "google-signin") ? 1 : 0

  triggers_replace = [
    module.app_secrets["google-signin"].secret_arn
  ]

  provisioner "local-exec" {
    command = "gh secret set GOOGLE_SIGNIN_SECRET_ARN -e ${terraform.workspace} -b \"${module.app_secrets["google-signin"].secret_arn}\" --repo BartsNCo/Backend"
  }
}
