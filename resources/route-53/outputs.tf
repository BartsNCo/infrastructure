# Route53 outputs

output "hosted_zone_id" {
  description = "Route53 hosted zone IDs by environment"
  value       = { for k, v in aws_route53_zone.subdomain : k => v.zone_id }
}

output "domains_name" {
  description = "The name of the root domain for this zone"
  value = { for v in var.subdomain : v.env_name => aws_route53_zone.subdomain[v.env_name].name }
}

output "hosted_zone_name_servers" {
  description = "Route53 hosted zone name servers by environment"
  value       = { for k, v in aws_route53_zone.subdomain : k => v.name_servers }
}

output "certificate_arn" {
  description = "ACM certificate ARNs by environment"
  value       = { for k, v in aws_acm_certificate.subdomain : k => v.arn }
}

output "certificate_domain_name" {
  description = "ACM certificate domain names by environment"
  value       = { for k, v in aws_acm_certificate.subdomain : k => v.domain_name }
}
