# Database - DocumentDB (MongoDB) Cluster

This Terraform configuration creates an Amazon DocumentDB cluster, which provides a MongoDB-compatible database for the Barts Tours VR platform.

## Overview

The database configuration provides:
- MongoDB-compatible DocumentDB cluster
- Secure VPC-based networking
- Automated backups and point-in-time recovery
- Scalable compute and storage
- Secrets Manager integration for credentials

## Resources Created

### Database Infrastructure
- **DocumentDB Cluster**: MongoDB-compatible database cluster
- **DocumentDB Instances**: Compute instances for the cluster
- **Subnet Group**: VPC subnets for database deployment
- **Security Groups**: Network access control
- **Secret Manager Secret**: Encrypted connection string storage
- **Jump Server**: EC2 instance for SSH tunnel access (t3.micro)
- **Key Pair**: AWS key pair for jump server SSH access

## Configuration

### Database Specifications

| Setting | Value | Description |
|---------|-------|-------------|
| **Engine** | `docdb` | Amazon DocumentDB |
| **Instance Class** | `db.t3.medium` | Cost-optimized instance type |
| **Storage** | Auto-scaling | Automatic storage scaling |
| **Backup Retention** | 7 days | Point-in-time recovery window |
| **Encryption** | Enabled | Data encryption at rest |

### Network Configuration

- **VPC**: Default VPC with private subnets
- **Security Groups**: VPC-only access (no public internet)
- **Port**: 27017 (standard MongoDB port)
- **SSL/TLS**: Required for all connections

## Usage

### Deploy Database

```bash
cd infrastructure/viewer-app/database

# Initialize Terraform
terraform init

# Select workspace
terraform workspace select development

# Plan deployment (provide credentials and SSH key)
terraform plan -var="mongodb_username=bart_root" -var="mongodb_password=YOUR_SECURE_PASSWORD" -var="public_key=YOUR_SSH_PUBLIC_KEY"

# Apply changes
terraform apply -var="mongodb_username=bart_root" -var="mongodb_password=YOUR_SECURE_PASSWORD" -var="public_key=YOUR_SSH_PUBLIC_KEY"

# Or use environment variables
export TF_VAR_mongodb_username="bart_root"
export TF_VAR_mongodb_password="YOUR_SECURE_PASSWORD"
export TF_VAR_public_key="ssh-ed25519 AAAAC3... your-email@example.com"
terraform apply
```

### Required Variables

| Variable | Description | Type | Sensitive |
|----------|-------------|------|-----------|
| `mongodb_username` | Database administrator username | `string` | No |
| `mongodb_password` | Database administrator password | `string` | Yes |
| `project_name` | Project identifier | `string` | No |
| `public_key` | SSH public key for jump server access | `string` | No |

## Connection Details

### Connection String Format

```
mongodb://username:password@cluster-endpoint:27017/?ssl=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false
```

### Secrets Manager Integration

The connection string is automatically stored in AWS Secrets Manager:

```json
{
  "MONGODB_URI": "mongodb://bart_root:password@barts-database-development.cluster-xxxxx.docdb.us-east-1.amazonaws.com:27017/?ssl=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
}
```

### Application Integration

Services access the database via the stored secret:

```hcl
# Backend service configuration
secrets = [
  {
    secret_manager_arn = local.viewer_app_database_mongodb_connection_secret_arn
    key                = "MONGODB_URI"
  }
]
```

## Security Features

### Network Security
- **VPC Isolation**: Database deployed in private subnets
- **Security Groups**: Access restricted to application subnets
- **No Public Access**: Database not accessible from internet

### Encryption
- **At Rest**: Data encrypted using AWS KMS
- **In Transit**: TLS/SSL required for all connections
- **Secrets**: Connection credentials encrypted in Secrets Manager

### Access Control
- **IAM Integration**: Database access via IAM roles
- **Username/Password**: Traditional MongoDB authentication
- **Certificate Validation**: SSL certificate verification

## Monitoring and Backup

### CloudWatch Metrics
- CPU utilization
- Memory usage
- Storage utilization
- Connection counts
- Read/write operations

### Backup Strategy
- **Automated Backups**: Daily snapshots with 7-day retention
- **Point-in-Time Recovery**: Restore to any second within backup window
- **Manual Snapshots**: On-demand backup creation
- **Cross-Region Copy**: Optional backup replication

## Performance Tuning

### Instance Sizing

```hcl
# Current configuration
instance_class = "db.t3.medium"

# Scaling options
# db.t3.medium  - 2 vCPU, 4 GB RAM  (Current)
# db.r5.large   - 2 vCPU, 16 GB RAM (Memory optimized)
# db.r5.xlarge  - 4 vCPU, 32 GB RAM (High performance)
```

### Read Replicas

```hcl
# Add read replicas for read-heavy workloads
resource "aws_docdb_cluster_instance" "cluster_instances" {
  count              = 2  # 1 primary + 1 replica
  identifier         = "${var.project_name}-database-${terraform.workspace}-${count.index}"
  cluster_identifier = aws_docdb_cluster.docdb.id
  instance_class     = var.instance_class
}
```

## Outputs

| Output | Description |
|--------|-------------|
| `mongodb_connection_secret_arn` | ARN of the connection string secret |
| `mongodb_endpoint` | DocumentDB cluster endpoint |
| `mongodb_port` | DocumentDB cluster port |
| `jumpserver_public_ip` | Public IP of the jump server |
| `jumpserver_instance_id` | Instance ID of the jump server |
| `ssh_tunnel_command` | SSH tunnel command to connect to DocumentDB |

## Integration with Other Components

### Backend Service

The backend service automatically receives the database connection:

```hcl
data "terraform_remote_state" "viewer_app_database" {
  backend = "s3"
  config = {
    bucket    = "barts-terraform-state-1750103475"
    key       = "viewer-app/database/terraform.tfstate"
    region    = "us-east-1"
    workspace = terraform.workspace
  }
}

locals {
  mongodb_connection_secret_arn = data.terraform_remote_state.viewer_app_database.outputs.mongodb_connection_secret_arn
}
```

## Database Management

### Remote Connection via Jump Server

The database includes a jump server for secure remote access via SSH tunnel.

#### 1. Create SSH Tunnel

```bash
# Get the jump server IP and DocumentDB endpoint
terraform output jumpserver_public_ip
terraform output mongodb_endpoint

# Create SSH tunnel (replace with your actual values)
ssh -i ~/.ssh/your_private_key -L 27017:<documentdb-endpoint>:27017 ec2-user@<jumpserver-ip> -N -f

# Example:
ssh -i ~/.ssh/jumpserver_key -L 27017:barts-mongodb-development.cluster-xxxxx.us-east-1.docdb.amazonaws.com:27017 ec2-user@34.227.117.18 -N -f

# Or use the provided command from Terraform output
$(terraform output -raw ssh_tunnel_command) -i ~/.ssh/your_private_key -N -f
```

#### 2. Download DocumentDB Certificate

```bash
# Download the certificate bundle (required for TLS/SSL)
wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
```

#### 3. Connect with mongosh

```bash
# Install mongosh (MongoDB Shell)
brew install mongosh  # macOS
# or visit: https://www.mongodb.com/try/download/shell

# Connect through the SSH tunnel (recommended method)
mongosh --host localhost:27017 \
  --username "$TF_VAR_mongodb_username" \
  --password "$TF_VAR_mongodb_password" \
  --tls \
  --tlsCAFile global-bundle.pem \
  --tlsAllowInvalidHostnames

# Alternative: Using connection string (requires URL-encoded password)
# Note: Special characters in password like % and # must be URL-encoded
mongosh "mongodb://${TF_VAR_mongodb_username}:${TF_VAR_mongodb_password}@localhost:27017/?tls=true&tlsCAFile=global-bundle.pem&tlsAllowInvalidHostnames=true&replicaSet=rs0&retryWrites=false"
```

#### Managing SSH Tunnels

```bash
# Check if tunnel is active
ps aux | grep "ssh.*-L 27017"

# Kill existing tunnel
pkill -f "ssh.*-L 27017"

# Test tunnel connectivity
telnet localhost 27017
```

### Direct Connection Testing (from VPC)

```bash
# Install MongoDB client
sudo apt-get install -y mongodb-clients

# Connect to cluster (from VPC)
mongo --ssl --host barts-database-development.cluster-xxxxx.docdb.us-east-1.amazonaws.com:27017 \
      --username bart_root --password
```

### Common Operations

```javascript
// MongoDB shell commands
use admin
db.createUser({
  user: "app_user",
  pwd: "secure_password",
  roles: [ { role: "readWrite", db: "tours" } ]
})

use tours
db.createCollection("panoramas")
db.panoramas.insertOne({name: "Test Tour", location: "Sample Location"})
```

## Maintenance

### Updates and Patches
- **Automatic Minor Updates**: Enabled for security patches
- **Major Version Updates**: Manual upgrade process
- **Maintenance Window**: Configurable low-traffic periods

### Monitoring
```bash
# Check cluster status
aws docdb describe-db-clusters --db-cluster-identifier barts-database-development

# View cluster metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/DocDB \
  --metric-name CPUUtilization \
  --dimensions Name=DBClusterIdentifier,Value=barts-database-development \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Average
```

## Cost Optimization

### Development Environment
- **Instance Type**: `db.t3.medium` for cost efficiency
- **Single Instance**: No read replicas in development
- **Backup Retention**: 7 days (minimum)
- **Storage**: Auto-scaling starts at 10GB

### Estimated Costs (us-east-1)
- **db.t3.medium**: ~$0.077/hour (~$55/month)
- **Storage**: ~$0.10/GB-month
- **Backup Storage**: Free for 7 days
- **Data Transfer**: Varies by usage

## Troubleshooting

### Common Issues

1. **Connection Timeout**: Check security groups and VPC routing
2. **Authentication Failed**: Verify username/password in Secrets Manager
3. **SSL Certificate Errors**: Ensure SSL is enabled and certificates are valid

### Debug Commands

```bash
# Test network connectivity
telnet barts-database-development.cluster-xxxxx.docdb.us-east-1.amazonaws.com 27017

# Check secret value
aws secretsmanager get-secret-value \
  --secret-id barts-mongodb-connection-development \
  --query SecretString --output text | jq

# View cluster logs
aws logs describe-log-groups --log-group-name-prefix "/aws/docdb"
```

## Best Practices

1. **Credentials**: Use strong passwords and rotate regularly
2. **Connections**: Implement connection pooling in applications
3. **Indexes**: Create appropriate indexes for query performance
4. **Monitoring**: Set up CloudWatch alarms for key metrics
5. **Backups**: Test restore procedures regularly