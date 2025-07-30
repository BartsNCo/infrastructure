locals {
  viewer_app_database_mongodb_connection_secret_arn = data.terraform_remote_state.viewer_app_database.outputs.mongodb_connection_secret_arn
  unity_assets_bucket_name = "bartsnco-main"
  unity_build_output_bucket_name = "${terraform.workspace}-unity-builds"
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
  role            = aws_iam_role.lambda_execution.arn
  handler         = "index.handler"
  runtime         = "nodejs22.x"
  timeout         = 900
  memory_size     = 3008
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  vpc_config {
    subnet_ids         = data.aws_subnets.default.ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      BUCKET_NAME = local.unity_assets_bucket_name
      MONGODB_SECRET_ARN = local.viewer_app_database_mongodb_connection_secret_arn
      ECS_TASK_DEFINITION = aws_ecs_task_definition.unity_builder.arn
      ECS_CLUSTER_NAME = "barts_viewer_cluster_${terraform.workspace}"  # Using default cluster, can be changed if needed
      ECS_SUBNET_IDS = join(",", data.aws_subnets.default.ids)
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
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.default.ids
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  
  private_dns_enabled = true

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
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.${var.aws_region}.ecs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.default.ids
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  
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
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
    description     = "Allow HTTPS from Lambda"
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
  network_mode            = "awsvpc"
  cpu                     = var.unity_builder_cpu
  memory                  = var.unity_builder_memory
  execution_role_arn      = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

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
    cpu_architecture       = "X86_64"
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
        Resource = local.viewer_app_database_mongodb_connection_secret_arn
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
