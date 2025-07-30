locals {
  viewer_app_database_mongodb_connection_secret_arn = data.terraform_remote_state.viewer_app_database.outputs.mongodb_connection_secret_arn
  unity_assets_bucket_name = "bartsnco-main"
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

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = local.unity_assets_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.unity_builder.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "image/"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}
