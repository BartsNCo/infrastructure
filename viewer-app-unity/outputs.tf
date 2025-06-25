output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.unity_webgl.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.unity_webgl.arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.unity_webgl.id
}

output "cloudfront_distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.unity_webgl.domain_name
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.unity_webgl.arn
}

output "unity_webgl_url" {
  description = "URL to access the Unity WebGL application"
  value       = "https://${local.subdomain}"
}