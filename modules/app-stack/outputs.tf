output "application_name" {
  description = "Elastic Beanstalk application name"
  value       = aws_elastic_beanstalk_application.this.name
}

output "application_arn" {
  description = "Elastic Beanstalk application ARN"
  value       = aws_elastic_beanstalk_application.this.arn
}

output "environments" {
  description = "Elastic Beanstalk environments"
  value = {
    for name, env in aws_elastic_beanstalk_environment.environments : name => {
      id          = env.id
      name        = env.name
      cname       = env.cname
      endpoint    = env.endpoint_url
      tier        = env.tier
      application = env.application
      url         = "https://${env.cname}"
    }
  }
}

output "service_role_arn" {
  description = "Elastic Beanstalk service role ARN"
  value       = aws_iam_role.beanstalk_service.arn
}

output "instance_profile_name" {
  description = "EC2 instance profile name"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "environment_urls" {
  description = "URLs for all environments"
  value = {
    for name, env in aws_elastic_beanstalk_environment.environments : name => "https://${env.cname}"
  }
}
