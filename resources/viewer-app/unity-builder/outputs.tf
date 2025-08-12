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

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer for SSH access"
  value       = aws_lb.unity_builder_ssh.dns_name
}

output "ssh_subdomain" {
  description = "SSH subdomain URL"
  value       = aws_route53_record.unity_builder_ssh.fqdn
}

output "ssh_connection_via_nlb" {
  value       = "ssh -i ec2-key ubuntu@${aws_route53_record.unity_builder_ssh.fqdn}"
  description = "SSH connection command via load balancer"
}

