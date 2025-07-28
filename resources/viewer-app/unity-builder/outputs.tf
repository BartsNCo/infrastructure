# Outputs for unity-builder module

output "task_definition_arn" {
  description = "ARN of the Unity builder task definition"
  value       = aws_ecs_task_definition.unity_builder.arn
}

output "task_definition_family" {
  description = "Family of the Unity builder task definition"
  value       = aws_ecs_task_definition.unity_builder.family
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for Unity builder"
  value       = aws_ecr_repository.unity_builder.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.unity_builder.name
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.s3_object_created.name
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.s3_object_created.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.unity_builder.name
}

output "security_group_id" {
  description = "ID of the security group for the Unity builder task"
  value       = aws_security_group.unity_builder.id
}

output "output_bucket_name" {
  description = "Name of the S3 bucket for Unity builder output"
  value       = aws_s3_bucket.unity_builder_output.id
}

output "output_bucket_arn" {
  description = "ARN of the S3 bucket for Unity builder output"
  value       = aws_s3_bucket.unity_builder_output.arn
}

output "output_bucket_url" {
  description = "URL of the S3 bucket for Unity builder output"
  value       = "s3://${aws_s3_bucket.unity_builder_output.id}"
}