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