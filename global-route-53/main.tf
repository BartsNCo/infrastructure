resource "aws_route53_zone" "dev_subdomain" {
  name = "dev.${var.domain_name}"

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Name        = "${var.project_name}-${var.environment}-dev-hosted-zone"
  }
}

# Create A record for dev subdomain pointing to your services
resource "aws_route53_record" "dev_root" {
  zone_id = aws_route53_zone.dev_subdomain.zone_id
  name    = "dev.${var.domain_name}"
  type    = "A"
  
  # Using alias to point to CloudFront or Load Balancer
  # This will need to be updated with actual target when services are deployed
  alias {
    name                   = "example-placeholder.cloudfront.net"  # Replace with actual CloudFront domain
    zone_id                = "Z2FDTNDATAQYW2"  # CloudFront hosted zone ID
    evaluate_target_health = false
  }
}

# SSL Certificate for the dev subdomain
# resource "aws_acm_certificate" "dev_subdomain" {
#   domain_name               = "dev.${var.domain_name}"
#   subject_alternative_names = [
#     "*.dev.${var.domain_name}"
#   ]
#   validation_method = "DNS"
#
#   lifecycle {
#     create_before_destroy = true
#   }
#
#   tags = {
#     Environment = var.environment
#     Project     = var.project_name
#     Name        = "${var.project_name}-${var.environment}-dev-ssl-cert"
#   }
# }

# DNS validation records for the certificate
# resource "aws_route53_record" "cert_validation" {
#   for_each = {
#     for dvo in aws_acm_certificate.dev_subdomain.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   }
#
#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = aws_route53_zone.dev_subdomain.zone_id
# }

# Certificate validation
# resource "aws_acm_certificate_validation" "dev_subdomain" {
#   certificate_arn         = aws_acm_certificate.dev_subdomain.arn
#   validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
#
#   timeouts {
#     create = "5m"
#   }
# }
