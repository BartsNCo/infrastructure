output "mongodb_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = aws_docdb_cluster.mongodb.endpoint
}

output "mongodb_port" {
  description = "DocumentDB cluster port"
  value       = aws_docdb_cluster.mongodb.port
}

output "mongodb_connection_string" {
  description = "MongoDB connection string"
  value       = "mongodb://${var.mongodb_username}:${var.mongodb_password}@${aws_docdb_cluster.mongodb.endpoint}:${aws_docdb_cluster.mongodb.port}/?ssl=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
  sensitive   = true
}

output "security_group_id" {
  description = "Security group ID for the database"
  value       = aws_security_group.mongodb.id
}

output "subnet_group_name" {
  description = "Database subnet group name"
  value       = aws_docdb_subnet_group.mongodb.name
}

output "cluster_identifier" {
  description = "DocumentDB cluster identifier"
  value       = aws_docdb_cluster.mongodb.cluster_identifier
}