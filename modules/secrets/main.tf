# Local variables
locals {
  policy_name_base = replace(title(replace(var.secret_name, "-", " ")), " ", "")
}

# Create the secret
resource "aws_secretsmanager_secret" "this" {
  name_prefix = "${var.secret_name}-"
  description = var.description

  # Optional KMS key for encryption
  kms_key_id = var.kms_key_id

  # Recovery window for deletion
  recovery_window_in_days = var.recovery_window_days

  tags = merge(
    var.tags,
    {
      Name        = var.secret_name
      Environment = var.environment
      Application = var.application_name
      Project     = var.project_name
    }
  )
}

# Create the secret version with the actual secret data
resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = var.secret_type == "string" ? var.secret_string : jsonencode(var.secret_data)
}

# Create IAM policy for reading the secret
resource "aws_iam_policy" "secret_read" {
  name        = "Allow${local.policy_name_base}SecretRead"
  description = "Policy to read secret ${var.secret_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadSecretValue"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = aws_secretsmanager_secret.this.arn
      },
      {
        Sid    = "DecryptSecret"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_id != null ? var.kms_key_id : "*"
        Condition = var.kms_key_id != null ? {} : {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.secret_name}-read-policy"
      Environment = var.environment
      Application = var.application_name
      Project     = var.project_name
    }
  )
}

# Create IAM policy for writing/managing the secret
resource "aws_iam_policy" "secret_write" {
  name        = "Allow${local.policy_name_base}SecretWrite"
  description = "Policy to write/manage secret ${var.secret_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageSecretValue"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:RestoreSecret",
          "secretsmanager:RotateSecret",
          "secretsmanager:TagResource",
          "secretsmanager:UntagResource"
        ]
        Resource = aws_secretsmanager_secret.this.arn
      },
      {
        Sid    = "EncryptDecryptSecret"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_id != null ? var.kms_key_id : "*"
        Condition = var.kms_key_id != null ? {} : {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.secret_name}-write-policy"
      Environment = var.environment
      Application = var.application_name
      Project     = var.project_name
    }
  )
}

# Data source to get current AWS region
data "aws_region" "current" {}

# Optional: Create rotation configuration
resource "aws_secretsmanager_secret_rotation" "this" {
  count = var.enable_rotation ? 1 : 0

  secret_id = aws_secretsmanager_secret.this.id

  rotation_rules {
    automatically_after_days = var.rotation_days
  }

  rotation_lambda_arn = var.rotation_lambda_arn
}

# Attach read-only policy to groups
resource "aws_iam_group_policy_attachment" "read_groups" {
  for_each = toset(var.read_groups)

  group      = each.value
  policy_arn = aws_iam_policy.secret_read.arn
}


# Attach read-only policy to users
resource "aws_iam_user_policy_attachment" "read_users" {
  for_each = toset(var.read_users)

  user       = each.value
  policy_arn = aws_iam_policy.secret_read.arn
}


# Attach both read and write policies to readwrite groups
resource "aws_iam_group_policy_attachment" "readwrite_groups_read" {
  for_each = toset(var.readwrite_groups)

  group      = each.value
  policy_arn = aws_iam_policy.secret_read.arn
}

resource "aws_iam_group_policy_attachment" "readwrite_groups_write" {
  for_each = toset(var.readwrite_groups)

  group      = each.value
  policy_arn = aws_iam_policy.secret_write.arn
}

# Attach both read and write policies to readwrite users
resource "aws_iam_user_policy_attachment" "readwrite_users_read" {
  for_each = toset(var.readwrite_users)

  user       = each.value
  policy_arn = aws_iam_policy.secret_read.arn
}

resource "aws_iam_user_policy_attachment" "readwrite_users_write" {
  for_each = toset(var.readwrite_users)

  user       = each.value
  policy_arn = aws_iam_policy.secret_write.arn
}
