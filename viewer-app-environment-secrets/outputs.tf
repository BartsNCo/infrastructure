output "secret_arns" {
  description = "ARNs of all created secrets"
  value       = { for k, v in module.app_secrets : k => v.secret_arn }
}

output "secret_names" {
  description = "Names of all created secrets"
  value       = { for k, v in module.app_secrets : k => v.secret_name }
}

output "secret_ids" {
  description = "IDs of all created secrets"
  value       = { for k, v in module.app_secrets : k => v.secret_id }
}

output "secret_version_ids" {
  description = "Version IDs of all secret versions"
  value       = { for k, v in module.app_secrets : k => v.secret_version_id }
}

output "read_policy_arns" {
  description = "ARNs of the IAM policies for reading the secrets"
  value       = { for k, v in module.app_secrets : k => v.read_policy_arn }
}

output "read_policy_names" {
  description = "Names of the IAM policies for reading the secrets"
  value       = { for k, v in module.app_secrets : k => v.read_policy_name }
}

output "read_policy_documents" {
  description = "The read policy documents in JSON format"
  value       = { for k, v in module.app_secrets : k => v.read_policy_document }
  sensitive   = false
}

output "write_policy_arns" {
  description = "ARNs of the IAM policies for writing/managing the secrets"
  value       = { for k, v in module.app_secrets : k => v.write_policy_arn }
}

output "write_policy_names" {
  description = "Names of the IAM policies for writing/managing the secrets"
  value       = { for k, v in module.app_secrets : k => v.write_policy_name }
}

output "write_policy_documents" {
  description = "The write policy documents in JSON format"
  value       = { for k, v in module.app_secrets : k => v.write_policy_document }
  sensitive   = false
}