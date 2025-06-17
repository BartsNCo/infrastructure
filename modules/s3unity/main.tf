resource "aws_s3_bucket" "unity-assests" {
  bucket = "unity-webgl-deployment"

  tags = {
    Name        = ""
    Environment = "Dev"
  }
}

# S3 bucket public access block - conditional based on allow_direct_s3_access
resource "aws_s3_bucket_public_access_block" "unity" {
  bucket = aws_s3_bucket.unity-assests.id

  block_public_acls       = !var.allow_direct_s3_access
  block_public_policy     = !var.allow_direct_s3_access
  ignore_public_acls      = !var.allow_direct_s3_access
  restrict_public_buckets = !var.allow_direct_s3_access
}

resource "aws_s3_bucket_website_configuration" "http-config" {
  bucket = aws_s3_bucket.unity-assests.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "unity" {
  comment = "OAI for Unity WebGL S3 bucket"
}

# S3 bucket policy to allow CloudFront access and optionally public read
resource "aws_s3_bucket_policy" "unity" {
  bucket = aws_s3_bucket.unity-assests.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "AllowCloudFrontAccess"
          Effect = "Allow"
          Principal = {
            AWS = aws_cloudfront_origin_access_identity.unity.iam_arn
          }
          Action   = "s3:GetObject"
          Resource = "${aws_s3_bucket.unity-assests.arn}/*"
        }
      ],
      var.allow_direct_s3_access ? [
        {
          Sid       = "PublicReadGetObject"
          Effect    = "Allow"
          Principal = "*"
          Action    = "s3:GetObject"
          Resource  = "${aws_s3_bucket.unity-assests.arn}/*"
        }
      ] : []
    )
  })
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "unity" {
  origin {
    domain_name = aws_s3_bucket.unity-assests.bucket_domain_name
    origin_id   = "S3-${aws_s3_bucket.unity-assests.bucket}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.unity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Unity WebGL CloudFront Distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.unity-assests.bucket}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # Custom error response for Unity WebGL
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.project_name}-unity-cloudfront-${var.environment}"
    Environment = var.environment
  }
}