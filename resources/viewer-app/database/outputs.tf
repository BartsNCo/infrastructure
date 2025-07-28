# Database outputs
output "mongodb_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = module.database.mongodb_endpoint
}

output "mongodb_port" {
  description = "DocumentDB cluster port"
  value       = module.database.mongodb_port
}

output "mongodb_connection_secret_arn" {
  description = "ARN of the Secrets Manager secret containing MongoDB connection string"
  value       = module.database.mongodb_connection_secret_arn
}

output "jumpserver_public_ip" {
  description = "Public IP of the jump server"
  value       = module.database.jumpserver_public_ip
}

output "jumpserver_instance_id" {
  description = "Instance ID of the jump server"
  value       = module.database.jumpserver_instance_id
}

output "ssh_tunnel_command" {
  description = "SSH tunnel command to connect to DocumentDB"
  value       = module.database.ssh_tunnel_command
}

