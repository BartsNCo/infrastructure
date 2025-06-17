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

# CloudFront outputs
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.unity.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.unity.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.unity.domain_name
}

output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = "https://${aws_cloudfront_distribution.unity.domain_name}"
}