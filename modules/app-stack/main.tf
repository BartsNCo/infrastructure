# Elastic Beanstalk Application
resource "aws_elastic_beanstalk_application" "this" {
  name        = "${var.project_name}_${var.application_name}_${var.environment}"
  description = var.application_description

  appversion_lifecycle {
    service_role          = aws_iam_role.beanstalk_service.arn
    max_count             = 128
    delete_source_from_s3 = true
  }

  tags = merge(
    {
      Name        = "${var.project_name}_${var.application_name}_${var.environment}"
      Environment = var.environment
      Application = "${var.project_name}_${var.application_name}"
      Project     = var.project_name
    },
    var.tags
  )
}

# Service Role for Elastic Beanstalk
resource "aws_iam_role" "beanstalk_service" {
  name = "${var.project_name}_${var.application_name}_${var.environment}_service_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "elasticbeanstalk.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.project_name}_${var.application_name}_${var.environment}_service_role"
      Environment = var.environment
      Application = "${var.project_name}_${var.application_name}"
      Project     = var.project_name
    },
    var.tags
  )
}

# Attach policies to service role
resource "aws_iam_role_policy_attachment" "beanstalk_service" {
  role       = aws_iam_role.beanstalk_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

resource "aws_iam_role_policy_attachment" "beanstalk_health" {
  role       = aws_iam_role.beanstalk_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

# EC2 Instance Profile Role
resource "aws_iam_role" "ec2_profile" {
  name = "${var.project_name}_${var.application_name}_${var.environment}_ec2_role"

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

  tags = merge(
    {
      Name        = "${var.project_name}_${var.application_name}_${var.environment}_ec2_role"
      Environment = var.environment
      Application = "${var.project_name}_${var.application_name}"
      Project     = var.project_name
    },
    var.tags
  )
}

# Attach policies to EC2 role
resource "aws_iam_role_policy_attachment" "web_tier" {
  role       = aws_iam_role.ec2_profile.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "worker_tier" {
  role       = aws_iam_role.ec2_profile.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

resource "aws_iam_role_policy_attachment" "multicontainer_docker" {
  role       = aws_iam_role.ec2_profile.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}_${var.application_name}_${var.environment}_ec2_profile"
  role = aws_iam_role.ec2_profile.name

  tags = merge(
    {
      Name        = "${var.project_name}_${var.application_name}_${var.environment}_ec2_profile"
      Environment = var.environment
      Application = "${var.project_name}_${var.application_name}"
      Project     = var.project_name
    },
    var.tags
  )
}

# Elastic Beanstalk Environments
resource "aws_elastic_beanstalk_environment" "environments" {
  for_each = var.environments

  name                = each.key
  application         = aws_elastic_beanstalk_application.this.name
  description         = each.value.description
  solution_stack_name = each.value.solution_stack_name
  tier                = each.value.tier

  # Default settings
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.ec2_profile.name
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = var.instance_type
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.beanstalk_service.arn
  }

  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  # Custom settings from variable
  dynamic "setting" {
    for_each = each.value.settings
    content {
      namespace = setting.value.namespace
      name      = setting.value.name
      value     = setting.value.value
    }
  }

  tags = merge(
    {
      Name        = each.key
      Environment = var.environment
      Application = "${var.project_name}_${var.application_name}"
      Project     = var.project_name
    },
    var.tags
  )
}