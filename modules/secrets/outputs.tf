output "secret_arn" {
  description = "ARN of the created secret"
  value       = aws_secretsmanager_secret.this.arn
}

output "secret_name" {
  description = "Name of the created secret"
  value       = aws_secretsmanager_secret.this.name
}

output "secret_id" {
  description = "ID of the created secret"
  value       = aws_secretsmanager_secret.this.id
}

output "secret_version_id" {
  description = "Version ID of the secret"
  value       = aws_secretsmanager_secret_version.this.version_id
}

output "read_policy_arn" {
  description = "ARN of the IAM policy for reading the secret"
  value       = aws_iam_policy.secret_read.arn
}

output "read_policy_name" {
  description = "Name of the IAM policy for reading the secret"
  value       = aws_iam_policy.secret_read.name
}

output "read_policy_id" {
  description = "ID of the IAM policy for reading the secret"
  value       = aws_iam_policy.secret_read.id
}

output "read_policy_document" {
  description = "The read policy document in JSON format"
  value       = aws_iam_policy.secret_read.policy
}

output "write_policy_arn" {
  description = "ARN of the IAM policy for writing/managing the secret"
  value       = aws_iam_policy.secret_write.arn
}

output "write_policy_name" {
  description = "Name of the IAM policy for writing/managing the secret"
  value       = aws_iam_policy.secret_write.name
}

output "write_policy_id" {
  description = "ID of the IAM policy for writing/managing the secret"
  value       = aws_iam_policy.secret_write.id
}

output "write_policy_document" {
  description = "The write policy document in JSON format"
  value       = aws_iam_policy.secret_write.policy
}

# Deprecated outputs for backward compatibility
output "access_policy_arn" {
  description = "DEPRECATED: Use read_policy_arn instead"
  value       = aws_iam_policy.secret_read.arn
}

output "access_policy_name" {
  description = "DEPRECATED: Use read_policy_name instead"
  value       = aws_iam_policy.secret_read.name
}

output "access_policy_id" {
  description = "DEPRECATED: Use read_policy_id instead"
  value       = aws_iam_policy.secret_read.id
}

output "access_policy_document" {
  description = "DEPRECATED: Use read_policy_document instead"
  value       = aws_iam_policy.secret_read.policy
}

output "attached_read_groups" {
  description = "List of groups with read-only access to the secret"
  value       = var.read_groups
}

output "attached_read_users" {
  description = "List of users with read-only access to the secret"
  value       = var.read_users
}

output "attached_readwrite_groups" {
  description = "List of groups with read-write access to the secret"
  value       = var.readwrite_groups
}

output "attached_readwrite_users" {
  description = "List of users with read-write access to the secret"
  value       = var.readwrite_users
}