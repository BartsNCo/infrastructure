locals {
  task_family = "${var.project_name}_unity_builder_${terraform.workspace}"
  tags = {
    Environment = terraform.workspace
    Project     = var.project_name
    Application = "unity-builder"
  }
}

# CloudWatch Log Group for the task
resource "aws_cloudwatch_log_group" "unity_builder" {
  name              = "/ecs/${local.task_family}"
  retention_in_days = 7
  tags              = local.tags
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_execution_role" {
  name = "${local.task_family}_execution_role"

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

  tags = local.tags
}

# IAM Role Policy for ECS Task Execution
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for pulling from ECR
resource "aws_iam_role_policy" "ecs_execution_ecr_policy" {
  name = "${local.task_family}_ecr_policy"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name = "${local.task_family}_task_role"

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

  tags = local.tags
}

# IAM Policy for S3 Access
resource "aws_iam_role_policy" "ecs_task_s3_policy" {
  name = "${local.task_family}_s3_policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::bartsnco-main",
          "arn:aws:s3:::bartsnco-main/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.unity_builder_output.arn,
          "${aws_s3_bucket.unity_builder_output.arn}/*"
        ]
      }
    ]
  })
}

# ECR Repository for the Unity Builder container
resource "aws_ecr_repository" "unity_builder" {
  name = "${var.project_name}_unity_builder_${terraform.workspace}"

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

# ECR Lifecycle Policy
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
  family                   = local.task_family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "unity-builder"
      image = "${aws_ecr_repository.unity_builder.repository_url}:latest"
      
      essential = true
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.unity_builder.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      environment = [
        {
          name  = "S3_BUCKET"
          value = "bartsnco-main"
        },
        {
          name  = "UNITY_PROJECT_PATH"
          value = "/app/BartsViewerBundlesBuilder"
        },
        {
          name  = "OUTPUT_S3_BUCKET"
          value = aws_s3_bucket.unity_builder_output.id
        }
      ]
      
      mountPoints = []
      volumesFrom = []
    }
  ])

  tags = local.tags
}

# EventBridge Rule for S3 Object Creation
resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name        = "${local.task_family}_s3_trigger"
  description = "Trigger Unity builder when objects are created in S3"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = ["bartsnco-main"]
      }
      object = {
        key = [{
          prefix = ""
        }]
      }
    }
  })

  tags = local.tags
}

# IAM Role for EventBridge to execute ECS tasks
resource "aws_iam_role" "eventbridge_ecs_role" {
  name = "${local.task_family}_eventbridge_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# IAM Policy for EventBridge to run ECS tasks
resource "aws_iam_role_policy" "eventbridge_ecs_policy" {
  name = "${local.task_family}_eventbridge_ecs_policy"
  role = aws_iam_role.eventbridge_ecs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = aws_ecs_task_definition.unity_builder.arn
        Condition = {
          ArnLike = {
            "ecs:cluster" = data.aws_ecs_cluster.main.arn
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      }
    ]
  })
}

# EventBridge Target to run ECS Task
resource "aws_cloudwatch_event_target" "ecs_task" {
  rule      = aws_cloudwatch_event_rule.s3_object_created.name
  target_id = "RunECSTask"
  arn       = data.aws_ecs_cluster.main.arn
  role_arn  = aws_iam_role.eventbridge_ecs_role.arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.unity_builder.arn
    launch_type         = "FARGATE"
    platform_version    = "LATEST"

    network_configuration {
      subnets          = data.aws_subnets.default.ids
      security_groups  = [aws_security_group.unity_builder.id]
      assign_public_ip = true
    }
  }

  input_transformer {
    input_paths = {
      bucket = "$.detail.bucket.name"
      key    = "$.detail.object.key"
    }
    input_template = jsonencode({
      containerOverrides = [{
        name = "unity-builder"
        environment = [
          {
            name  = "S3_OBJECT_KEY"
            value = "<key>"
          },
          {
            name  = "S3_BUCKET"
            value = "<bucket>"
          }
        ]
      }]
    })
  }
}

# Security Group for Unity Builder Task
resource "aws_security_group" "unity_builder" {
  name        = "${local.task_family}_sg"
  description = "Security group for Unity Builder ECS task"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = local.tags
}

# S3 Bucket for Unity Builder Output
resource "aws_s3_bucket" "unity_builder_output" {
  bucket = "${var.project_name}-unity-builder-output-${terraform.workspace}"
  
  tags = merge(local.tags, {
    Purpose = "Unity asset bundle output storage"
  })
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "unity_builder_output" {
  bucket = aws_s3_bucket.unity_builder_output.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "unity_builder_output" {
  bucket = aws_s3_bucket.unity_builder_output.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "unity_builder_output" {
  bucket = aws_s3_bucket.unity_builder_output.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    
    filter {}
  }

  rule {
    id     = "cleanup-old-builds"
    status = "Enabled"

    expiration {
      days = 90
    }
    
    filter {
      prefix = "builds/"
    }
  }
}

# S3 Bucket Notification Configuration
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = "bartsnco-main"

  eventbridge = true
}