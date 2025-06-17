# Database outputs
output "mongodb_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = module.database.mongodb_endpoint
}

output "mongodb_port" {
  description = "DocumentDB cluster port"
  value       = module.database.mongodb_port
}

output "mongodb_connection_string" {
  description = "MongoDB connection string"
  value       = module.database.mongodb_connection_string
  sensitive   = true
}

# S3 Unity outputs
output "s3unity_bucket_name" {
  description = "S3 Unity bucket name"
  value       = module.s3unity.bucket_name
}

output "s3unity_bucket_arn" {
  description = "S3 Unity bucket ARN"
  value       = module.s3unity.bucket_arn
}

output "s3unity_website_endpoint" {
  description = "S3 Unity bucket website endpoint"
  value       = module.s3unity.website_endpoint
}

# CloudFront outputs
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.s3unity.cloudfront_distribution_id
}

output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = module.s3unity.cloudfront_url
}