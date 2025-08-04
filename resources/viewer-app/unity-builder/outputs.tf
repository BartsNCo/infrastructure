output "ecr_repository_url" {
  description = "URL of the ECR repository for Unity builder image"
  value       = aws_ecr_repository.unity_builder.repository_url
}

output "lambda_function_name" {
  description = "Name of the Unity builder Lambda function"
  value       = aws_lambda_function.unity_builder.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Unity builder Lambda function"
  value       = aws_lambda_function.unity_builder.arn
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.unity_builder.arn
}

output "ecs_task_definition_family" {
  description = "Family name of the ECS task definition"
  value       = aws_ecs_task_definition.unity_builder.family
}

output "ftps_server_endpoint" {
  description = "FTPS server endpoint for uploading Unity builds"
  value       = try(aws_transfer_server.unity_builds_ftps.endpoint, "VPC endpoint - use custom hostname")
}

output "ftps_elastic_ips" {
  description = "Elastic IP addresses for FTPS VPC endpoint"
  value       = aws_eip.ftps_endpoint[*].public_ip
}

output "ftps_server_id" {
  description = "FTPS server ID"
  value       = aws_transfer_server.unity_builds_ftps.id
}

output "ftps_custom_hostname" {
  description = "FTPS custom hostname"
  value       = "ftps.${local.domain_name}"
}

output "ftps_bucket_name" {
  description = "S3 bucket name for Unity build outputs"
  value       = aws_s3_bucket.unity_build_output.id
}

output "ftps_connection_info" {
  description = "FTPS connection information"
  value = {
    host     = "ftps.${local.domain_name}"
    port     = 21
    username = "${terraform.workspace}-unity-builds"
    protocol = "FTPS (FTP over TLS)"
  }
}

output "ftps_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing FTPS credentials"
  value       = aws_secretsmanager_secret.ftps_credentials.arn
}

output "ftps_credentials_secret_name" {
  description = "Name of the Secrets Manager secret containing FTPS credentials"
  value       = aws_secretsmanager_secret.ftps_credentials.name
}