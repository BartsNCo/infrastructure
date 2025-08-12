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

output "ec2_instance_id" {
  value       = aws_instance.unity_builder.id
  description = "ID of the EC2 instance"
}


output "unity_builder_secrets_arn" {
  description = "ARN of the Unity builder secrets in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.unity_builder_secrets.arn
}

output "ssm_connection_command" {
  value       = "aws ssm start-session --target ${aws_instance.unity_builder.id}"
  description = "AWS SSM Session Manager connection command"
}

output "ssm_connection_command_with_region" {
  value       = "aws ssm start-session --target ${aws_instance.unity_builder.id} --region ${var.aws_region}"
  description = "AWS SSM Session Manager connection command with region"
}

output "ssm_connection_command_ubuntu" {
  value       = "aws ssm start-session --target ${aws_instance.unity_builder.id} --document-name ${aws_ssm_document.ubuntu_session.name}"
  description = "AWS SSM Session Manager connection command as ubuntu user"
}

