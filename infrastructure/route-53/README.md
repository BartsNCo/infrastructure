# Route 53 - Shared DNS Configuration

This Terraform configuration manages shared DNS infrastructure including hosted zones and SSL certificates for all environments in the Barts Tours VR platform.

## Overview

The Route 53 configuration provides:
- DNS hosted zones for each environment subdomain
- SSL/TLS certificates with automatic DNS validation
- Centralized domain management across environments

## Resources Created

### DNS Infrastructure
- **Hosted Zones**: Creates `{subdomain}.{domain}` zones for each environment
- **SSL Certificates**: ACM certificates for `{subdomain}.{domain}` and `*.{subdomain}.{domain}`
- **Certificate Validation**: Automatic DNS-based certificate validation

### Current Configuration
- **Domain Pattern**: `{environment}.{domain_name}`
- **Wildcard Support**: `*.{environment}.{domain_name}`
- **Validation Method**: DNS-based validation

## Variables

| Variable | Description | Type | Required |
|----------|-------------|------|----------|
| `project_name` | Name of the project for resource naming | `string` | Yes |
| `domain_name` | Base domain name | `string` | Yes |
| `subdomain` | List of subdomain configurations | `list(object)` | Yes |

### Subdomain Configuration

Each subdomain object should contain:
```hcl
{
  env_name  = "development"  # Environment name
  subdomain = "dev"          # Subdomain prefix
}
```

## Usage

This configuration is shared across all environments and should be deployed once per domain setup.

### Deploy

```bash
cd infrastructure/route-53

# Initialize
terraform init

# Plan changes
terraform plan

# Apply
terraform apply
```

### Environment Variables

Required in `.envrc` or equivalent:
```bash
export AWS_PROFILE=barts-admin
export AWS_REGION=us-east-1
```

## Outputs

| Output | Description |
|--------|-------------|
| `hosted_zone_id` | Map of environment names to hosted zone IDs |
| `certificate_arn` | Map of environment names to certificate ARNs |
| `name_servers` | Map of environment names to name server lists |

## Integration

Other configurations reference these outputs via Terraform remote state:

```hcl
data "terraform_remote_state" "global_route53" {
  backend = "s3"
  config = {
    bucket = "barts-terraform-state-1750103475"
    key    = "global/route53/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  route53_zone_id = data.terraform_remote_state.global_route53.outputs.hosted_zone_id[terraform.workspace]
  certificate_arn = data.terraform_remote_state.global_route53.outputs.certificate_arn[terraform.workspace]
}
```

## DNS Records

Currently, A records are commented out in the configuration. When services are deployed, uncomment and configure the alias records to point to your load balancers or CloudFront distributions.

Example for CloudFront integration:
```hcl
resource "aws_route53_record" "app_root" {
  zone_id = aws_route53_zone.subdomain[each.key].zone_id
  name    = "${each.value}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.app.domain_name
    zone_id                = aws_cloudfront_distribution.app.hosted_zone_id
    evaluate_target_health = false
  }
}
```

## Security Considerations

- Certificates are automatically validated via DNS
- All resources are tagged with environment and project information
- Certificate lifecycle management with `create_before_destroy`
- 5-minute timeout for certificate validation

## Maintenance

- Certificates auto-renew through AWS Certificate Manager
- DNS validation records are managed automatically
- Monitor certificate expiration in ACM console
- Update subdomain configurations as new environments are added