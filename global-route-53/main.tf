resource "aws_route53_zone" "subdomain" {
  for_each = { for v in var.subdomain : v.env_name => v.subdomain }
  name     = "${each.value}.${var.domain_name}"

  tags = {
    Environment = each.key
    Project     = var.project_name
    Name        = "${var.project_name}-${each.key}-hosted-zone"
  }
}

# Create A record for dev subdomain pointing to your services
# resource "aws_route53_record" "dev_root" {
#   for_each = toset(var.subdomain)
#   zone_id = aws_route53_zone.dev_subdomain.zone_id
#   name    = "${each.value}.${var.domain_name}"
#   type    = "A"
#
#   # Using alias to point to CloudFront or Load Balancer
#   # This will need to be updated with actual target when services are deployed
#   alias {
#     name                   = "example-placeholder.cloudfront.net" # Replace with actual CloudFront domain
#     zone_id                = aws_route53_zone.subdomain.id
#     evaluate_target_health = false
#   }
# }

# SSL Certificate for the dev subdomain
resource "aws_acm_certificate" "subdomain" {
  for_each    = { for v in var.subdomain : v.env_name => v.subdomain }
  domain_name = "${each.value}.${var.domain_name}"
  subject_alternative_names = [
    "*.${each.value}.${var.domain_name}"
  ]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = each.key
    Project     = var.project_name
    Name        = "${var.project_name}-${each.key}-dev-ssl-cert"
  }
}

locals {
  cert_validation_records = { for v in flatten([for s in var.subdomain : [
    for dvo in aws_acm_certificate.subdomain[s.env_name].domain_validation_options : {
      key      = "${s.env_name}-${dvo.domain_name}"
      name     = dvo.resource_record_name
      record   = dvo.resource_record_value
      type     = dvo.resource_record_type
      env_name = s.env_name
    }
    ]
  ]) : v.key => v }
}

# DNS validation records for the certificate
resource "aws_route53_record" "cert_validation" {
  for_each = local.cert_validation_records

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.subdomain[each.value.env_name].zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "subdomain" {
  for_each        = { for s in var.subdomain : s.env_name => s.subdomain }
  certificate_arn = aws_acm_certificate.subdomain[each.key].arn
  validation_record_fqdns = [
    for record_key, record_data in local.cert_validation_records :
    aws_route53_record.cert_validation[record_key].fqdn if record_data.env_name == each.key
  ]

  timeouts {
    create = "5m"
  }
}

