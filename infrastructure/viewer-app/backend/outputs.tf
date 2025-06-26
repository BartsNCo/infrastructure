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
output "s3_unity_cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.s3unity.cloudfront_distribution_id
}

output "s3_unity_cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = module.s3unity.cloudfront_url
}


# Backend service outputs
output "backend_service_url" {
  description = "Backend service URL"
  value       = module.backend.service_url
}

output "backend_service_dns" {
  description = "Backend service DNS name"
  value       = module.backend.service_dns
}
