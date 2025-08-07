locals {
  viewer_app_database_mongodb_connection_secret_arn = data.terraform_remote_state.viewer_app_database.outputs.mongodb_connection_secret_arn
  unity_assets_bucket_name                          = "bartsnco-main"
  unity_build_output_bucket_name                    = "${terraform.workspace}-unity-builds"

  # Route53 values from remote state
  route53_zone_id = data.terraform_remote_state.route53.outputs.hosted_zone_id[terraform.workspace]
  domain_name     = data.terraform_remote_state.route53.outputs.domains_name[terraform.workspace]
}

# GitHub token secret for Unity repository access
resource "aws_secretsmanager_secret" "github_token" {
  name                    = "${terraform.workspace}-unity-builder-github-token"
  description             = "GitHub token for Unity repository access"
  recovery_window_in_days = 0

  tags = {
    Name        = "${terraform.workspace}-unity-builder-github-token"
    Environment = terraform.workspace
  }
}

resource "aws_secretsmanager_secret_version" "github_token" {
  secret_id = aws_secretsmanager_secret.github_token.id
  secret_string = jsonencode({
    GITHUB_TOKEN = var.github_token
  })
}

resource "null_resource" "lambda_dependencies" {
  provisioner "local-exec" {
    command = "cd ${path.module}/lambda-function && npm install --production"
  }

  triggers = {
    package_json = filemd5("${path.module}/lambda-function/package.json")
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-function"
  output_path = "${path.module}/lambda_function.zip"

  depends_on = [null_resource.lambda_dependencies]
}

resource "aws_security_group" "lambda_sg" {
  name        = "${terraform.workspace}-unity-builder-lambda-sg"
  description = "Security group for Unity Builder Lambda"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${terraform.workspace}-unity-builder-lambda-sg"
  }
}

resource "aws_lambda_function" "unity_builder" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${terraform.workspace}-unity-asset-builder"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  timeout          = 900
  memory_size      = 3008
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  vpc_config {
    subnet_ids         = data.aws_subnets.default.ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      BUCKET_NAME           = local.unity_assets_bucket_name
      MONGODB_SECRET_ARN    = local.viewer_app_database_mongodb_connection_secret_arn
      ECS_TASK_DEFINITION   = aws_ecs_task_definition.unity_builder.arn
      ECS_CLUSTER_NAME      = "barts_viewer_cluster_${terraform.workspace}" # Using default cluster, can be changed if needed
      ECS_SUBNET_IDS        = join(",", data.aws_subnets.default.ids)
      ECS_SECURITY_GROUP_ID = aws_security_group.lambda_sg.id
    }
  }
}

resource "aws_iam_role" "lambda_execution" {
  name = "${terraform.workspace}-unity-builder-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_policy" "lambda_secrets_policy" {
  name        = "${terraform.workspace}-unity-builder-lambda-secrets-policy"
  description = "IAM policy for Lambda to access Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = local.viewer_app_database_mongodb_connection_secret_arn
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_s3_policy" {
  name        = "${terraform.workspace}-unity-builder-lambda-s3-policy"
  description = "IAM policy for Lambda to access S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${local.unity_assets_bucket_name}",
          "arn:aws:s3:::${local.unity_assets_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_secrets" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_secrets_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

resource "aws_iam_policy" "lambda_ecs_policy" {
  name        = "${terraform.workspace}-unity-builder-lambda-ecs-policy"
  description = "IAM policy for Lambda to run ECS tasks"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:StopTask"
        ]
        Resource = [
          aws_ecs_task_definition.unity_builder.arn,
          "arn:aws:ecs:${var.aws_region}:*:task/${terraform.workspace}-unity-builder/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_task_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_ecs" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_ecs_policy.arn
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "${title(terraform.workspace)}AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.unity_builder.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${local.unity_assets_bucket_name}"
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id             = data.aws_vpc.default.id
  service_name       = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = data.aws_subnets.default.ids
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]

  private_dns_enabled = true

  tags = {
    Name = "${terraform.workspace}-unity-builder-secretsmanager-endpoint"
  }
}
resource "aws_vpc_endpoint" "kms" {
  vpc_id             = data.aws_vpc.default.id
  service_name       = "com.amazonaws.us-east-1.kms"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = data.aws_subnets.default.ids
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]
  tags = {
    Name = "${terraform.workspace}-unity-builder-secretsmanager-endpoint"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.default.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.default.ids

  tags = {
    Name = "${terraform.workspace}-unity-builder-s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecs" {
  vpc_id             = data.aws_vpc.default.id
  service_name       = "com.amazonaws.${var.aws_region}.ecs"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = data.aws_subnets.default.ids
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]

  private_dns_enabled = true

  tags = {
    Name = "${terraform.workspace}-unity-builder-ecs-endpoint"
  }
}

resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "${terraform.workspace}-unity-builder-vpc-endpoint-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from Lambda"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${terraform.workspace}-unity-builder-vpc-endpoint-sg"
  }
}

resource "aws_s3_bucket" "unity_build_output" {
  bucket_prefix = "${local.unity_build_output_bucket_name}-"
  force_destroy = true

  tags = {
    Name        = "Unity Build Output"
    Environment = terraform.workspace
  }
}

# S3 bucket policy to allow CloudFront access
resource "aws_s3_bucket_policy" "unity_build_output" {
  bucket = aws_s3_bucket.unity_build_output.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.unity_build_output.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.unity_assets.arn
          }
        }
      }
    ]
  })
}

# ACM Certificate for CloudFront (must be in us-east-1)
resource "aws_acm_certificate" "unity_assets" {
  provider          = aws.us_east_1
  domain_name       = "unityassets.${local.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${terraform.workspace}-unity-assets-cert"
    Environment = terraform.workspace
  }
}

# DNS validation for ACM certificate
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.unity_assets.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.route53_zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "unity_assets" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.unity_assets.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# CloudFront Origin Access Control (newer than OAI)
resource "aws_cloudfront_origin_access_control" "unity_assets" {
  name                              = "${terraform.workspace}-unity-assets-oac"
  description                       = "OAC for Unity Assets"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "unity_assets" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Unity Assets Distribution - ${terraform.workspace}"
  default_root_object = "index.html"

  aliases = ["unityassets.${local.domain_name}"]

  origin {
    domain_name              = aws_s3_bucket.unity_build_output.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.unity_build_output.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.unity_assets.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.unity_build_output.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0 # No caching by default
    max_ttl                = 0
    compress               = true
  }

  # Custom cache behavior for ServerData path
  ordered_cache_behavior {
    path_pattern     = "ServerData/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.unity_build_output.id}"

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.unity_assets.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name        = "${terraform.workspace}-unity-assets-cdn"
    Environment = terraform.workspace
  }
}

# Output the CloudFront domain
output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.unity_assets.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.unity_assets.id
}

# Route53 record for the unityassets subdomain
resource "aws_route53_record" "unity_assets" {
  zone_id = local.route53_zone_id
  name    = "unityassets.${local.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.unity_assets.domain_name
    zone_id                = aws_cloudfront_distribution.unity_assets.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route53 record for IPv6
resource "aws_route53_record" "unity_assets_ipv6" {
  zone_id = local.route53_zone_id
  name    = "unityassets.${local.domain_name}"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.unity_assets.domain_name
    zone_id                = aws_cloudfront_distribution.unity_assets.hosted_zone_id
    evaluate_target_health = false
  }
}

output "unity_assets_url" {
  description = "Unity assets URL"
  value       = "https://unityassets.${local.domain_name}"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = local.unity_assets_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.unity_builder.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "image/"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_ecr_repository" "unity_builder" {
  name                 = "${terraform.workspace}-unity-builder"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${terraform.workspace}-unity-builder"
    Environment = terraform.workspace
  }
}

resource "aws_ecr_lifecycle_policy" "unity_builder" {
  repository = aws_ecr_repository.unity_builder.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "unity_builder" {
  family                   = "${terraform.workspace}-unity-builder"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.unity_builder_cpu
  memory                   = var.unity_builder_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  ephemeral_storage {
    size_in_gib = var.unity_builder_ephemeral_storage
  }

  container_definitions = jsonencode([
    {
      name  = "unity-builder"
      image = "${aws_ecr_repository.unity_builder.repository_url}:${var.unity_builder_image_tag}"

      environment = [
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        },
        {
          name  = "S3_BUCKET"
          value = local.unity_assets_bucket_name
        },
        {
          name  = "S3_OUTPUT_BUCKET"
          value = aws_s3_bucket.unity_build_output.id
        }
      ]

      secrets = [
        {
          name      = "MONGODB_URI"
          valueFrom = "${local.viewer_app_database_mongodb_connection_secret_arn}:MONGODB_URI::"
        },
        {
          name      = "GITHUB_TOKEN"
          valueFrom = "${aws_secretsmanager_secret.github_token.arn}:GITHUB_TOKEN::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_task.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "unity-builder"
        }
      }

      essential = true
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

# CloudWatch Log Group for ECS Task
resource "aws_cloudwatch_log_group" "ecs_task" {
  name              = "/ecs/${terraform.workspace}-unity-builder"
  retention_in_days = 7
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${terraform.workspace}-unity-builder-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# ECS Task Role (for the container itself)
resource "aws_iam_role" "ecs_task_role" {
  name = "${terraform.workspace}-unity-builder-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policies to ECS Task Execution Role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Policy for ECS Task Execution Role to access secrets
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "${terraform.workspace}-ecs-task-execution-secrets"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          local.viewer_app_database_mongodb_connection_secret_arn,
          aws_secretsmanager_secret.github_token.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy for ECS Task Role (container permissions)
resource "aws_iam_role_policy" "ecs_task_s3_access" {
  name = "${terraform.workspace}-ecs-task-s3-access"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${local.unity_assets_bucket_name}",
          "arn:aws:s3:::${local.unity_assets_bucket_name}/*",
          aws_s3_bucket.unity_build_output.arn,
          "${aws_s3_bucket.unity_build_output.arn}/*"
        ]
      }
    ]
  })
}
