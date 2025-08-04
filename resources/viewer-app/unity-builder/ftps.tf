# Generate random password for FTPS user
resource "random_password" "ftps_password" {
  length  = 32
  special = true
}

# Store FTPS credentials in Secrets Manager
resource "aws_secretsmanager_secret" "ftps_credentials" {
  name        = "${terraform.workspace}-unity-builds-ftps-credentials"
  description = "FTPS credentials for Unity builds output bucket"

  tags = {
    Name        = "${terraform.workspace}-unity-builds-ftps-credentials"
    Environment = terraform.workspace
  }
}

resource "aws_secretsmanager_secret_version" "ftps_credentials" {
  secret_id = aws_secretsmanager_secret.ftps_credentials.id
  secret_string = jsonencode({
    username = "${terraform.workspace}-unity-builds"
    password = random_password.ftps_password.result
    endpoint = aws_transfer_server.unity_builds_ftps.endpoint
    bucket   = aws_s3_bucket.unity_build_output.id
  })
}

# Lambda function for custom identity provider (password authentication)
resource "aws_lambda_function" "ftps_identity_provider" {
  filename         = data.archive_file.ftps_identity_provider_zip.output_path
  function_name    = "${terraform.workspace}-ftps-identity-provider"
  role             = aws_iam_role.ftps_identity_provider_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  timeout          = 60
  source_code_hash = data.archive_file.ftps_identity_provider_zip.output_base64sha256

  environment {
    variables = {
      SECRETS_MANAGER_SECRET_ID = aws_secretsmanager_secret.ftps_credentials.id
      S3_BUCKET_NAME            = aws_s3_bucket.unity_build_output.id
      USER_ROLE_ARN             = aws_iam_role.ftps_user_role.arn
    }
  }

  tags = {
    Name        = "${terraform.workspace}-ftps-identity-provider"
    Environment = terraform.workspace
  }
}

# Create directory for Lambda code
resource "null_resource" "create_lambda_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/ftps-identity-provider"
  }
}

# Package.json for Lambda dependencies
resource "local_file" "ftps_identity_provider_package" {
  filename = "${path.module}/ftps-identity-provider/package.json"
  content  = <<-EOT
{
  "name": "ftps-identity-provider",
  "version": "1.0.0",
  "description": "FTPS Identity Provider Lambda",
  "main": "index.js",
  "dependencies": {
    "@aws-sdk/client-secrets-manager": "^3.600.0"
  }
}
EOT

  depends_on = [null_resource.create_lambda_dir]
}

# Install Lambda dependencies
resource "null_resource" "install_lambda_dependencies" {
  provisioner "local-exec" {
    command = "cd ${path.module}/ftps-identity-provider && npm install --production"
  }

  triggers = {
    package_json = local_file.ftps_identity_provider_package.content
  }

  depends_on = [local_file.ftps_identity_provider_package]
}

# Create the Lambda code for identity provider
resource "local_file" "ftps_identity_provider_code" {
  filename = "${path.module}/ftps-identity-provider/index.js"
  content  = <<-EOT
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const secretsManager = new SecretsManagerClient();

exports.handler = async (event) => {
    console.log('Full authentication event:', JSON.stringify(event, null, 2));
    
    // Transfer Family sends the event in a specific format
    const username = event.username;
    const password = event.password;
    const serverId = event.serverId;
    const protocol = event.protocol;
    const sourceIp = event.sourceIp;
    
    console.log('Parsed credentials - Username:', username, 'ServerId:', serverId, 'Protocol:', protocol);
    
    if (!username || !password) {
        console.log('Missing username or password');
        return {};
    }
    
    try {
        // Get credentials from Secrets Manager
        console.log('Fetching secret from:', process.env.SECRETS_MANAGER_SECRET_ID);
        const command = new GetSecretValueCommand({
            SecretId: process.env.SECRETS_MANAGER_SECRET_ID
        });
        const secretData = await secretsManager.send(command);
        
        const credentials = JSON.parse(secretData.SecretString);
        console.log('Secret fetched successfully. Expected username:', credentials.username);
        
        // Verify credentials
        if (username === credentials.username && password === credentials.password) {
            const response = {
                Role: process.env.USER_ROLE_ARN,
                HomeDirectoryType: 'PATH',
                HomeDirectory: '/' + process.env.S3_BUCKET_NAME,
                Policy: ''  // Empty policy means use the role's policy
            };
            
            console.log('Authentication successful. Response:', JSON.stringify(response, null, 2));
            return response;
        } else {
            console.log('Authentication failed. Username match:', username === credentials.username, 'Password match:', password === credentials.password);
            return {};
        }
    } catch (error) {
        console.error('Error during authentication:', error);
        console.error('Error stack:', error.stack);
        return {};
    }
};
EOT

  depends_on = [null_resource.create_lambda_dir]
}

# Archive the Lambda function
data "archive_file" "ftps_identity_provider_zip" {
  type        = "zip"
  source_dir  = "${path.module}/ftps-identity-provider"
  output_path = "${path.module}/ftps-identity-provider.zip"

  depends_on = [
    local_file.ftps_identity_provider_code,
    local_file.ftps_identity_provider_package,
    null_resource.install_lambda_dependencies
  ]
}

# IAM Role for Identity Provider Lambda
resource "aws_iam_role" "ftps_identity_provider_lambda" {
  name = "${terraform.workspace}-ftps-identity-provider-lambda-role"

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

  tags = {
    Name        = "${terraform.workspace}-ftps-identity-provider-lambda-role"
    Environment = terraform.workspace
  }
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "ftps_identity_provider_lambda_basic" {
  role       = aws_iam_role.ftps_identity_provider_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Policy for Lambda to access Secrets Manager
resource "aws_iam_role_policy" "ftps_identity_provider_lambda_secrets" {
  name = "${terraform.workspace}-ftps-identity-provider-secrets-policy"
  role = aws_iam_role.ftps_identity_provider_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.ftps_credentials.arn
      }
    ]
  })
}

# Lambda permission for Transfer Family
resource "aws_lambda_permission" "allow_transfer_family_ftps" {
  statement_id  = "AllowExecutionFromTransferFamily"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ftps_identity_provider.function_name
  principal     = "transfer.amazonaws.com"
  source_arn    = aws_transfer_server.unity_builds_ftps.arn
}

# Security group for FTPS VPC endpoint
resource "aws_security_group" "ftps_endpoint_sg" {
  name        = "${terraform.workspace}-ftps-endpoint-sg"
  description = "Security group for FTPS VPC endpoint"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 21
    to_port     = 21
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "FTP control channel"
  }

  ingress {
    from_port   = 990
    to_port     = 990
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "FTPS implicit SSL/TLS"
  }

  ingress {
    from_port   = 8192
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "FTPS passive mode data transfer"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${terraform.workspace}-ftps-endpoint-sg"
  }
}

# Elastic IPs for VPC endpoint
resource "aws_eip" "ftps_endpoint" {
  count  = length(data.aws_subnets.default.ids) > 1 ? 1 : length(data.aws_subnets.default.ids)
  domain = "vpc"

  tags = {
    Name = "${terraform.workspace}-ftps-endpoint-eip-${count.index}"
  }
}

# AWS Transfer Family FTPS Server with VPC endpoint
resource "aws_transfer_server" "unity_builds_ftps" {
  identity_provider_type = "AWS_LAMBDA"
  function               = aws_lambda_function.ftps_identity_provider.arn
  protocols              = ["FTPS"]
  endpoint_type          = "VPC"

  # FTPS requires a certificate
  certificate = aws_acm_certificate.ftps_cert.arn

  endpoint_details {
    vpc_id                 = data.aws_vpc.default.id
    subnet_ids             = length(data.aws_subnets.default.ids) > 1 ? [data.aws_subnets.default.ids[0]] : data.aws_subnets.default.ids
    security_group_ids     = [aws_security_group.ftps_endpoint_sg.id]
    address_allocation_ids = aws_eip.ftps_endpoint[*].id
  }

  # Configure passive mode port range
  structured_log_destinations = [aws_cloudwatch_log_group.ftps_logs.arn]

  tags = {
    Name        = "${terraform.workspace}-unity-builds-ftps"
    Environment = terraform.workspace
  }

  depends_on = [aws_acm_certificate_validation.ftps_cert]
}

# CloudWatch Log Group for FTPS server
resource "aws_cloudwatch_log_group" "ftps_logs" {
  name              = "/aws/transfer/${terraform.workspace}-unity-builds-ftps"
  retention_in_days = 7
}

# ACM Certificate for FTPS
resource "aws_acm_certificate" "ftps_cert" {
  domain_name       = "ftps.${local.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${terraform.workspace}-ftps-cert"
    Environment = terraform.workspace
  }
}

# DNS validation for ACM certificate
resource "aws_route53_record" "ftps_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.ftps_cert.domain_validation_options : dvo.domain_name => {
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
resource "aws_acm_certificate_validation" "ftps_cert" {
  certificate_arn         = aws_acm_certificate.ftps_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.ftps_cert_validation : record.fqdn]
}

# Route53 record for FTPS server
resource "aws_route53_record" "ftps_server" {
  zone_id = local.route53_zone_id
  name    = "ftps.${local.domain_name}"
  type    = "A"
  ttl     = 300
  records = aws_eip.ftps_endpoint[*].public_ip
}

# IAM Role for FTPS Users
resource "aws_iam_role" "ftps_user_role" {
  name = "${terraform.workspace}-unity-builds-ftps-user-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${terraform.workspace}-unity-builds-ftps-user-role"
    Environment = terraform.workspace
  }
}

# IAM Policy for FTPS Users to access the output bucket
resource "aws_iam_role_policy" "ftps_user_policy" {
  name = "${terraform.workspace}-unity-builds-ftps-user-policy"
  role = aws_iam_role.ftps_user_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowListingOfBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.unity_build_output.arn
      },
      {
        Sid    = "AllowAllS3ActionsOnBucketContents"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion",
          "s3:GetObjectVersionTagging",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging",
          "s3:GetObjectAcl",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.unity_build_output.arn}/*"
      }
    ]
  })
}

# CloudWatch Log Group for Identity Provider Lambda
resource "aws_cloudwatch_log_group" "ftps_identity_provider_logs" {
  name              = "/aws/lambda/${terraform.workspace}-ftps-identity-provider"
  retention_in_days = 7
}