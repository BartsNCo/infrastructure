# Unity Assets - S3 + CloudFront CDN

This Terraform configuration creates a comprehensive S3 and CloudFront distribution specifically optimized for Unity WebGL content delivery in the Barts Tours VR platform.

## Overview

The Unity assets infrastructure provides:
- S3 bucket for Unity WebGL build storage
- CloudFront CDN for global content delivery
- Optimized caching policies for Unity-specific file types
- CORS support for cross-origin requests
- Custom domain with SSL/TLS termination
- Security headers for Unity WebGL compatibility

## Resources Created

### Storage Infrastructure
- **S3 Bucket**: Private bucket for Unity WebGL assets
- **Bucket Versioning**: Version control for asset updates
- **Public Access Block**: Security controls to prevent accidental public access
- **Bucket Policy**: CloudFront-only access permissions

### CDN Infrastructure
- **CloudFront Distribution**: Global content delivery network
- **Origin Access Identity**: Secure S3 access from CloudFront
- **Response Headers Policy**: Unity WebGL-specific headers including CORS
- **Custom Cache Behaviors**: Optimized caching for different file types

### DNS Integration
- **Route53 A Record**: IPv4 domain resolution
- **Route53 AAAA Record**: IPv6 domain resolution
- **Custom Domain**: `vr.dev.bartsnco.com.br`

## Unity WebGL Optimization

### Specialized Cache Behaviors

The configuration includes optimized caching for Unity-specific file types:

#### JavaScript Files (*.js)
- **TTL**: 1 day default, 1 year maximum
- **Compression**: Enabled
- **Headers**: Content-Type forwarded

#### CSS Files (*.css)
- **TTL**: 1 day default, 1 year maximum
- **Compression**: Enabled
- **Headers**: Content-Type forwarded

#### Unity Data Files (*.data)
- **TTL**: 1 day default, 1 year maximum
- **Compression**: Disabled (pre-compressed)
- **Headers**: Content-Type, Content-Encoding forwarded

#### WebAssembly Files (*.wasm)
- **TTL**: 1 day default, 1 year maximum
- **Compression**: Disabled (binary format)
- **Headers**: Content-Type, Content-Encoding forwarded

#### Unity Web Files (*.unityweb)
- **TTL**: 1 day default, 1 year maximum
- **Compression**: Disabled (pre-compressed)
- **Headers**: Content-Type, Content-Encoding forwarded

#### Addressable Assets (*.bundle, *.hash, catalog_*.json)
- **Bundle Files**: Long-term caching (1 year) for immutable assets
- **Hash Files**: Short-term caching (5 minutes) for catalog updates
- **Catalog Files**: Short-term caching (5 minutes) for dynamic content

## CORS Configuration

### Cross-Origin Support
```hcl
cors_config {
  access_control_allow_credentials = false
  access_control_max_age_sec       = 600
  origin_override                  = true

  access_control_allow_headers {
    items = ["*"]
  }

  access_control_allow_methods {
    items = ["GET", "HEAD", "OPTIONS"]
  }

  access_control_allow_origins {
    items = ["*"]
  }
}
```

### Unity-Specific Security Headers
```hcl
custom_headers_config {
  items {
    header   = "Cross-Origin-Embedder-Policy"
    value    = "require-corp"
    override = false
  }
  items {
    header   = "Cross-Origin-Opener-Policy"
    value    = "same-origin"
    override = false
  }
}
```

## Domain Configuration

### Environment-Based Subdomains
- **Development**: `vr.dev.bartsnco.com.br`
- **Staging**: `vr.staging.bartsnco.com.br` (when configured)
- **Production**: `vr.bartsnco.com.br` (when configured)

### SSL/TLS Configuration
- **Certificate**: ACM-managed certificate from Route53 configuration
- **TLS Version**: Minimum TLSv1.2_2021
- **SSL Method**: SNI-only (cost-effective)

## Usage

### Deploy Unity Assets Infrastructure

```bash
cd infrastructure/viewer-app/unity-assets

# Initialize Terraform
terraform init

# Select workspace
terraform workspace select development

# Plan deployment
terraform plan

# Apply changes
terraform apply
```

### Prerequisites

Ensure these components are deployed first:
1. Route53 (shared configuration for DNS and certificates)

## Content Deployment

### Manual Upload
```bash
# Upload Unity WebGL build to S3
aws s3 sync ./Build/ s3://barts-unity-webgl-development/ --delete

# Create CloudFront invalidation
aws cloudfront create-invalidation \
  --distribution-id E1234567890123 \
  --paths "/*"
```

### CI/CD Integration
```yaml
# GitHub Actions example
- name: Deploy to S3
  run: |
    aws s3 sync ./Build/ s3://${{ secrets.S3_BUCKET_NAME }}/ --delete
    
- name: Invalidate CloudFront
  run: |
    aws cloudfront create-invalidation \
      --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
      --paths "/*"
```

## Performance Optimization

### Caching Strategy

#### Long-term Caching (1 year)
- JavaScript and CSS files
- Unity data files (.data, .wasm, .unityweb)
- Asset bundles (.bundle)

#### Short-term Caching (5 minutes)
- Catalog files (.hash, catalog_*.json)
- Dynamic content requiring frequent updates

#### Default Caching (1 hour)
- HTML files and other static assets

### Content Delivery
- **Global Edge Locations**: CloudFront's worldwide network
- **Compression**: Automatic compression for text-based files
- **HTTP/2**: Enabled for improved performance
- **IPv6**: Full IPv6 support

## Security Features

### Access Control
- **Origin Access Identity**: S3 bucket accessible only via CloudFront
- **Private S3 Bucket**: No direct public access
- **IAM Policies**: Least-privilege access for deployment

### Security Headers
- **HTTPS Only**: Redirects all HTTP traffic to HTTPS
- **Cross-Origin Policies**: Unity WebGL compatibility headers
- **Content Security**: Prevents unauthorized access

## Integration with Backend

### Backend S3 Access
The backend service has permissions to upload content:

```hcl
# Backend service configuration
s3_bucket_names = [
  module.s3unity.bucket_name,  # Unity assets bucket
  "bartsnco-main"              # Additional storage
]
```

### Upload Endpoints
- **Backend API**: `/api/upload/unity`
- **Direct Upload**: Pre-signed URLs for large files
- **Batch Upload**: Multiple file upload support

## Monitoring and Analytics

### CloudWatch Metrics
- **Cache Hit Ratio**: CDN performance monitoring
- **Origin Requests**: S3 request patterns
- **Error Rates**: 4xx and 5xx error tracking
- **Data Transfer**: Bandwidth usage monitoring

### CloudFront Logs
```bash
# Enable access logging (optional)
logging_config {
  include_cookies = false
  bucket         = aws_s3_bucket.cloudfront_logs.bucket_domain_name
  prefix         = "unity-assets/"
}
```

## Cost Optimization

### Development Environment Costs
- **S3 Storage**: ~$0.023/GB-month (Standard)
- **CloudFront**: $0.085/GB for first 10 TB
- **Data Transfer**: Varies by region and usage
- **Requests**: $0.0075 per 10,000 HTTPS requests

### Cost Reduction Strategies
- **Cache Optimization**: Long TTLs for static assets
- **Compression**: Reduced data transfer costs
- **Regional Optimization**: Use appropriate edge locations

## Addressable Assets Support

### Unity Addressables Integration
The configuration includes specific optimizations for Unity Addressables:

#### Asset Bundles (*.bundle)
- Long-term caching for immutable content
- No compression (pre-optimized by Unity)
- Content-Encoding header support

#### Catalog Management
- Short TTL for catalog files to enable dynamic updates
- Compressed JSON catalog files
- Hash file support for integrity checking

### Addressables Workflow
1. **Build**: Unity generates addressable content
2. **Upload**: CI/CD uploads bundles and catalogs
3. **Catalog Update**: New catalog points to updated assets
4. **Client Update**: Unity client downloads new catalog
5. **Asset Loading**: On-demand asset bundle loading

## Troubleshooting

### Common Issues

1. **CORS Errors**: Check origin domains in CORS configuration
2. **MIME Type Issues**: Verify Content-Type headers for Unity files
3. **Loading Failures**: Check security headers for Unity WebGL compatibility
4. **Cache Issues**: Invalidate CloudFront distribution after updates

### Debug Commands

```bash
# Check S3 bucket contents
aws s3 ls s3://barts-unity-webgl-development/ --recursive

# Test CDN endpoint
curl -I https://vr.dev.bartsnco.com.br/index.html

# Check CloudFront distribution
aws cloudfront get-distribution --id E1234567890123

# View invalidation status
aws cloudfront list-invalidations --distribution-id E1234567890123
```

### Unity-Specific Debug
```bash
# Test Unity WebGL files
curl -H "Accept-Encoding: gzip" https://vr.dev.bartsnco.com.br/Build/build.data
curl -H "Accept-Encoding: br" https://vr.dev.bartsnco.com.br/Build/build.wasm

# Check CORS headers
curl -H "Origin: https://dev.bartsnco.com.br" \
     -H "Access-Control-Request-Method: GET" \
     -X OPTIONS https://vr.dev.bartsnco.com.br/
```

## Best Practices

### Content Management
1. **Version Control**: Use S3 versioning for rollback capability
2. **Atomic Updates**: Upload complete builds before invalidation
3. **Testing**: Validate Unity builds before deployment
4. **Monitoring**: Set up alerts for error rates and performance

### Performance
1. **Compression**: Let Unity handle compression for binary files
2. **Caching**: Use appropriate TTLs for different content types
3. **Invalidation**: Minimize invalidations to reduce costs
4. **Preloading**: Consider DNS prefetch and preconnect hints

### Security
1. **Access Control**: Regular review of S3 bucket policies
2. **Monitoring**: CloudTrail logging for access auditing
3. **Updates**: Keep CloudFront and S3 configurations current
4. **Testing**: Regular security testing of deployed content

## Future Enhancements

### Potential Improvements
- **Edge Computing**: Lambda@Edge for dynamic content
- **Analytics**: Real User Monitoring for Unity WebGL performance
- **Multi-Region**: Additional CloudFront origins for redundancy
- **Automation**: Advanced CI/CD pipelines for Unity builds
- **Compression**: Brotli compression for better performance