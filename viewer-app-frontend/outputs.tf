# ECS Cluster outputs
output "ecs_cluster_id" {
  description = "ECS cluster ID"
  value       = local.viewer_app_ecs_cluster_id
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = data.terraform_remote_state.viewer_app_ecs_cluster.outputs.cluster_arn
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = data.terraform_remote_state.viewer_app_ecs_cluster.outputs.cluster_name
}

# frontend service outputs
output "frontend_service_url" {
  description = "frontend service URL"
  value       = module.frontend.service_url
}

output "frontend_service_dns" {
  description = "frontend service DNS name"
  value       = module.frontend.service_dns
}
