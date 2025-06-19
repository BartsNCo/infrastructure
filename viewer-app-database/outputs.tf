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

