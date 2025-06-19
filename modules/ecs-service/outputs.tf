# Output values for ecs-service module

# Load Balancer outputs
output "service_dns" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "service_url" {
  description = "The full URL of the service"
  value       = "http://${aws_lb.main.dns_name}"
}

output "load_balancer_arn" {
  description = "The ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "load_balancer_zone_id" {
  description = "The zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "The ARN of the target group"
  value       = aws_lb_target_group.main.arn
}

output "alb_security_group_id" {
  description = "The ID of the ALB security group"
  value       = aws_security_group.alb.id
}

# ECR repository URI
output "ecr_repository_uri" {
  description = "The private URI of the ECR repository"
  value       = aws_ecr_repository.main.repository_url
}

output "ecr_repository_name" {
  description = "The name of the ECR repository"
  value       = aws_ecr_repository.main.name
}

# ECS Service details
output "ecs_service_name" {
  description = "The name of the ECS service"
  value       = aws_ecs_service.main.name
}

output "ecs_task_definition_arn" {
  description = "The ARN of the ECS task definition"
  value       = aws_ecs_task_definition.main.arn
}

# Security group IDs
output "ecs_security_group_id" {
  description = "The ID of the ECS service security group"
  value       = aws_security_group.ecs_service.id
}

# CloudWatch Log Group
output "log_group_name" {
  description = "The name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.main.name
}
