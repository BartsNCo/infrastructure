output "bucket_name" {
  description = "S3 Unity bucket name"
  value       = aws_s3_bucket.unity-assests.bucket
}

output "bucket_arn" {
  description = "S3 Unity bucket ARN"
  value       = aws_s3_bucket.unity-assests.arn
}

output "bucket_domain_name" {
  description = "S3 Unity bucket domain name"
  value       = aws_s3_bucket.unity-assests.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "S3 Unity bucket regional domain name"
  value       = aws_s3_bucket.unity-assests.bucket_regional_domain_name
}

output "website_endpoint" {
  description = "S3 Unity bucket website endpoint"
  value       = aws_s3_bucket_website_configuration.http-config.website_endpoint
}