output "mongodb_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = aws_docdb_cluster.mongodb.endpoint
}

output "mongodb_port" {
  description = "DocumentDB cluster port"
  value       = aws_docdb_cluster.mongodb.port
}

output "mongodb_connection_secret_arn" {
  description = "ARN of the Secrets Manager secret containing MongoDB connection string"
  value       = aws_secretsmanager_secret.mongodb_connection.arn
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

output "jumpserver_public_ip" {
  description = "Public IP of the jump server"
  value       = var.create_jumpserver ? aws_instance.jumpserver[0].public_ip : null
}

output "jumpserver_instance_id" {
  description = "Instance ID of the jump server"
  value       = var.create_jumpserver ? aws_instance.jumpserver[0].id : null
}

output "ssh_tunnel_command" {
  description = "SSH tunnel command to connect to DocumentDB"
  value       = var.create_jumpserver ? "ssh -L 27017:${aws_docdb_cluster.mongodb.endpoint}:27017 ec2-user@${aws_instance.jumpserver[0].public_ip}" : null
}