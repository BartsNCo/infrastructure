output "dev_hosted_zone_id" {
  description = "The hosted zone ID for the dev subdomain"
  value       = aws_route53_zone.dev_subdomain.zone_id
}

output "dev_hosted_zone_name_servers" {
  description = "The name servers for the dev subdomain - configure these in your domain registrar"
  value       = aws_route53_zone.dev_subdomain.name_servers
}

output "dev_domain_name" {
  description = "The domain name for the dev hosted zone"
  value       = aws_route53_zone.dev_subdomain.name
}

output "dev_subdomain_fqdn" {
  description = "The fully qualified domain name for the dev subdomain"
  value       = aws_route53_record.dev_root.fqdn
}

# SSL certificate outputs (commented out until domain is configured)
# output "ssl_certificate_arn" {
#   description = "The ARN of the SSL certificate for dev subdomain"
#   value       = aws_acm_certificate_validation.dev_subdomain.certificate_arn
# }

# output "ssl_certificate_domain_validation_options" {
#   description = "The domain validation options for the certificate"
#   value       = aws_acm_certificate.dev_subdomain.domain_validation_options
# }

output "dns_configuration_instructions" {
  description = "Instruções para configurar o domínio externo"
  value       = <<-EOT
    Para configurar dev.${var.domain_name} para apontar para AWS:
    
    1. Faça login no seu registrador de domínio (onde você comprou ${var.domain_name})
    2. Encontre as configurações de DNS para ${var.domain_name}
    3. Crie um registro NS para o subdomínio 'dev' apontando para estes servidores de nome do AWS Route53:
       ${join("\n       ", aws_route53_zone.dev_subdomain.name_servers)}
    
    4. Salve as alterações (a propagação pode levar de 24 a 48 horas)
    
    Uma vez configurado:
    - dev.${var.domain_name} será gerenciado inteiramente pelo AWS Route53
    
    Nota: Os recursos de certificado SSL estão comentados até que o domínio seja configurado.
    Descomente os recursos de certificado em main.tf após a delegação do domínio estar completa.
    
    Nota: Atualize o destino do alias em main.tf com seu domínio real do CloudFront ou Load Balancer.
  EOT
}