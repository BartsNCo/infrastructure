# Main resources for ecs-service module

# ECR Repository for the container
resource "aws_ecr_repository" "main" {
  name = "${var.project_name}_${var.application_name}_${var.environment}"

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    Application = var.application_name
  })
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Security Group for ECS Service
resource "aws_security_group" "ecs_service" {
  name_prefix = "${var.project_name}-${var.application_name}-${var.environment}-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}_${var.application_name}_sg_${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    Application = var.application_name
  })
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}_${var.application_name}_execution_role_${var.environment}"

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

  tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    Application = var.application_name
  })
}

# Attach ECS Task Execution Role Policy
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for secrets access
resource "aws_iam_role_policy" "secrets_policy" {
  count = length(var.container_definitions.secrets) > 0 ? 1 : 0
  name  = "${var.project_name}_${var.application_name}_secrets_policy_${var.environment}"
  role  = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds",
          "kms:Decrypt"
        ],
        Resource = [
          for secret in var.container_definitions.secrets : secret.secret_manager_arn
        ]
      }
    ]
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.project_name}_${var.application_name}_${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = var.container_definitions.name
      image = var.container_definitions.image != "" ? var.container_definitions.image : (var.docker_image != "public.ecr.aws/docker/library/busybox:latest" ? var.docker_image : "public.ecr.aws/docker/library/busybox:latest")

      # Default command for busybox to keep running
      command = (var.container_definitions.image == "" && var.docker_image == "public.ecr.aws/docker/library/busybox:latest") ? ["tail", "-f", "/dev/null"] : null

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = var.container_definitions.environment_variables

      secrets = [
        for secret in var.container_definitions.secrets : {
          valueFrom = "${secret.secret_manager_arn}:${secret.key}::"
          name      = secret.key
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])

  lifecycle {
    ignore_changes = [container_definitions]
  }

  tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    Application = var.application_name
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.project_name}_${var.application_name}_${var.environment}"
  retention_in_days = 7

  tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    Application = var.application_name
  })
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = "${var.project_name}_${var.application_name}_${var.environment}"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    Application = var.application_name
  })
}

