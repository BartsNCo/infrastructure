resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2-instance-key"
  public_key = file("${path.module}/ec2/ec2-key.pub")
}

resource "aws_security_group" "ec2_ssh" {
  name        = "ec2-ssh-access"
  description = "Security group for EC2 SSH access"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-ssh-security-group"
  }
}

resource "aws_instance" "unity_builder" {
  ami           = var.unity_builder_ami_id
  instance_type = "c5a.xlarge"
  key_name      = aws_key_pair.ec2_key.key_name

  iam_instance_profile = aws_iam_instance_profile.ec2_ssm.name

  vpc_security_group_ids = [aws_security_group.ec2_ssh.id]

  root_block_device {
    volume_type = "gp3"
    volume_size = 60
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    # Write environment variables to a file that can be sourced
    cat > /home/ubuntu/.unity_builder_env << 'ENV'
    export S3_INPUT_BUCKET="bartsnco-main"
    export S3_OUTPUT_BUCKET="${aws_s3_bucket.unity_build_output.id}"
    export AWS_DEFAULT_REGION="${var.aws_region}"
    export MONGODB_SECRET_ARN="${data.terraform_remote_state.viewer_app_database.outputs.mongodb_connection_secret_arn}"
    export UNITY_BUILDER_SECRET_ARN="${aws_secretsmanager_secret.unity_builder_secrets.arn}"
    ENV
    
    # Make it readable by ubuntu user
    chown ubuntu:ubuntu /home/ubuntu/.unity_builder_env
    chmod 644 /home/ubuntu/.unity_builder_env
    
    # Add to bashrc so it's automatically sourced
    echo "source /home/ubuntu/.unity_builder_env" >> /home/ubuntu/.bashrc
  EOF

  tags = {
    Name = "${terraform.workspace}-unity-builder-ec2"
  }
}

# IAM role for EC2 instance to enable SSM
resource "aws_iam_role" "ec2_ssm_role" {
  name = "${terraform.workspace}-unity-builder-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach SSM managed policy to the role
resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Policy for S3 access (input and output buckets)
resource "aws_iam_role_policy" "ec2_s3_access" {
  name = "${terraform.workspace}-unity-builder-ec2-s3-policy"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::bartsnco-main",
          "arn:aws:s3:::bartsnco-main/*",
          "arn:aws:s3:::${terraform.workspace}-unity-builds-*",
          "arn:aws:s3:::${terraform.workspace}-unity-builds-*/*"
        ]
      }
    ]
  })
}

# Policy for Secrets Manager access (MongoDB credentials)
resource "aws_iam_role_policy" "ec2_secrets_access" {
  name = "${terraform.workspace}-unity-builder-ec2-secrets-policy"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          data.terraform_remote_state.viewer_app_database.outputs.mongodb_connection_secret_arn,
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:${terraform.workspace}-unity-builder-secrets-*"
        ]
      }
    ]
  })
}

# Instance profile for EC2
resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${terraform.workspace}-unity-builder-ec2-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# Stop the instance after creation
resource "null_resource" "stop_instance" {
  depends_on = [aws_instance.unity_builder]

  provisioner "local-exec" {
    command = "aws ec2 stop-instances --instance-ids ${aws_instance.unity_builder.id} --region ${var.aws_region} || true"
  }

  triggers = {
    instance_id = aws_instance.unity_builder.id
  }
}
