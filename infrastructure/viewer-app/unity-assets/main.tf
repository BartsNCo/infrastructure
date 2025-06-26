# Local values from remote states
locals {
  route53_zone_id = data.terraform_remote_state.global_route53.outputs.hosted_zone_id[terraform.workspace]
  certificate_arn = data.terraform_remote_state.global_route53.outputs.certificate_arn[terraform.workspace]
  bucket_name     = "${var.project_name}-unity-webgl-${terraform.workspace}"
  # Map workspace to subdomain - development workspace uses dev subdomain
  env_subdomain = terraform.workspace == "development" ? "dev" : terraform.workspace
  subdomain     = "vr.${local.env_subdomain}.bartsnco.com.br"
}

# S3 bucket for Unity WebGL content
resource "aws_s3_bucket" "unity_webgl" {
  bucket = local.bucket_name

  tags = {
    Name        = "${var.project_name}-unity-${terraform.workspace}"
    Environment = terraform.workspace
    Application = "${var.project_name}_${var.application_name}"
    Project     = var.project_name
  }
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "unity_webgl" {
  bucket = aws_s3_bucket.unity_webgl.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "unity_webgl" {
  bucket = aws_s3_bucket.unity_webgl.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "unity_webgl" {
  comment = "OAI for ${local.bucket_name}"
}

# S3 bucket policy for CloudFront access
resource "aws_s3_bucket_policy" "unity_webgl" {
  bucket = aws_s3_bucket.unity_webgl.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.unity_webgl.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.unity_webgl.arn}/*"
      }
    ]
  })
}

# Response headers policy for Unity WebGL with CORS support
resource "aws_cloudfront_response_headers_policy" "unity_webgl" {
  name = "${var.project_name}-unity-webgl-${terraform.workspace}"

  cors_config {
    access_control_allow_credentials = false
    access_control_max_age_sec       = 600
    origin_override                  = true

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS"]
    }

    access_control_allow_origins {
      items = ["*"]
    }

    access_control_expose_headers {
      items = ["Content-Length", "Content-Type", "Content-Encoding"]
    }
  }

  custom_headers_config {
    items {
      header   = "Cross-Origin-Embedder-Policy"
      value    = "require-corp"
      override = false
    }
    items {
      header   = "Cross-Origin-Opener-Policy"
      value    = "same-origin"
      override = false
    }
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "unity_webgl" {
  origin {
    domain_name = aws_s3_bucket.unity_webgl.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.unity_webgl.bucket}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.unity_webgl.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Unity WebGL Distribution for ${local.subdomain}"
  default_root_object = "index.html"

  aliases = [local.subdomain]

  # Default cache behavior for HTML files
  default_cache_behavior {
    allowed_methods                = ["GET", "HEAD", "OPTIONS"]
    cached_methods                 = ["GET", "HEAD"]
    target_origin_id               = "S3-${aws_s3_bucket.unity_webgl.bucket}"
    compress                       = true
    viewer_protocol_policy         = "redirect-to-https"
    response_headers_policy_id     = aws_cloudfront_response_headers_policy.unity_webgl.id

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

  # Cache behavior for JavaScript files
  ordered_cache_behavior {
    path_pattern               = "*.js"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "S3-${aws_s3_bucket.unity_webgl.bucket}"
    compress                   = true
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.unity_webgl.id

    forwarded_values {
      query_string = false
      headers      = ["Content-Type"]
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  # Cache behavior for CSS files
  ordered_cache_behavior {
    path_pattern               = "*.css"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "S3-${aws_s3_bucket.unity_webgl.bucket}"
    compress                   = true
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.unity_webgl.id

    forwarded_values {
      query_string = false
      headers      = ["Content-Type"]
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  # Cache behavior for Unity WebGL data files (.data, .wasm, .unityweb)
  ordered_cache_behavior {
    path_pattern               = "*.data"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "S3-${aws_s3_bucket.unity_webgl.bucket}"
    compress                   = false
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.unity_webgl.id

    forwarded_values {
      query_string = false
      headers      = ["Content-Type", "Content-Encoding"]
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  # Cache behavior for WASM files
  ordered_cache_behavior {
    path_pattern               = "*.wasm"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "S3-${aws_s3_bucket.unity_webgl.bucket}"
    compress                   = false
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.unity_webgl.id

    forwarded_values {
      query_string = false
      headers      = ["Content-Type", "Content-Encoding"]
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  # Cache behavior for Unity asset bundles
  ordered_cache_behavior {
    path_pattern               = "*.unityweb"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "S3-${aws_s3_bucket.unity_webgl.bucket}"
    compress                   = false
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.unity_webgl.id

    forwarded_values {
      query_string = false
      headers      = ["Content-Type", "Content-Encoding"]
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  # Cache behavior for Addressable asset bundles
  ordered_cache_behavior {
    path_pattern               = "*.bundle"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "S3-${aws_s3_bucket.unity_webgl.bucket}"
    compress                   = false
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.unity_webgl.id

    forwarded_values {
      query_string = false
      headers      = ["Content-Type", "Content-Encoding"]
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  # Cache behavior for Addressable catalog files
  ordered_cache_behavior {
    path_pattern               = "*.hash"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "S3-${aws_s3_bucket.unity_webgl.bucket}"
    compress                   = true
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.unity_webgl.id

    forwarded_values {
      query_string = false
      headers      = ["Content-Type"]
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 300
    max_ttl     = 3600
  }

  # Cache behavior for Addressable catalog JSON files
  ordered_cache_behavior {
    path_pattern               = "catalog_*.json"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "S3-${aws_s3_bucket.unity_webgl.bucket}"
    compress                   = true
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.unity_webgl.id

    forwarded_values {
      query_string = false
      headers      = ["Content-Type"]
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 300
    max_ttl     = 3600
  }

  # Remove the custom error responses that redirect everything to index.html
  # This was causing the MIME type issues

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = local.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name        = "${var.project_name}-unity-cloudfront-${terraform.workspace}"
    Environment = terraform.workspace
    Application = "${var.project_name}_${var.application_name}"
    Project     = var.project_name
  }
}

# Route53 A record for subdomain
resource "aws_route53_record" "unity_webgl" {
  zone_id = local.route53_zone_id
  name    = local.subdomain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.unity_webgl.domain_name
    zone_id                = aws_cloudfront_distribution.unity_webgl.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 AAAA record for IPv6
resource "aws_route53_record" "unity_webgl_ipv6" {
  zone_id = local.route53_zone_id
  name    = local.subdomain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.unity_webgl.domain_name
    zone_id                = aws_cloudfront_distribution.unity_webgl.hosted_zone_id
    evaluate_target_health = false
  }
}

# Note: Cache invalidation needs to be done manually or via CI/CD
# Run this command after applying terraform and uploading files:
# aws cloudfront create-invalidation --distribution-id $(terraform output cloudfront_distribution_id) --paths "/*"