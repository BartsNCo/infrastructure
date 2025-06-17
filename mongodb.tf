# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group for MongoDB (DocumentDB)
resource "aws_security_group" "mongodb" {
  name        = "${var.project_name}-mongodb-${terraform.workspace}"
  description = "Security group for MongoDB DocumentDB cluster"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Public access - use with caution
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-mongodb-${terraform.workspace}"
    Environment = terraform.workspace
  }
}

# Subnet group for DocumentDB
resource "aws_docdb_subnet_group" "mongodb" {
  name       = "${var.project_name}-mongodb-${terraform.workspace}"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name        = "${var.project_name}-mongodb-subnet-group-${terraform.workspace}"
    Environment = terraform.workspace
  }
}

# DocumentDB cluster (AWS managed MongoDB-compatible)
resource "aws_docdb_cluster" "mongodb" {
  cluster_identifier      = "${var.project_name}-mongodb-${terraform.workspace}"
  engine                  = "docdb"
  master_username         = var.mongodb_username
  master_password         = var.mongodb_password
  backup_retention_period = 1
  preferred_backup_window = "07:00-09:00"
  skip_final_snapshot     = true
  db_subnet_group_name    = aws_docdb_subnet_group.mongodb.name
  vpc_security_group_ids  = [aws_security_group.mongodb.id]

  tags = {
    Name        = "${var.project_name}-mongodb-${terraform.workspace}"
    Environment = terraform.workspace
  }
}

# DocumentDB cluster instance (cheapest possible)
resource "aws_docdb_cluster_instance" "mongodb" {
  count              = 1
  identifier         = "${var.project_name}-mongodb-${terraform.workspace}-${count.index}"
  cluster_identifier = aws_docdb_cluster.mongodb.id
  instance_class     = "db.t3.medium" # Cheapest available instance class

  tags = {
    Name        = "${var.project_name}-mongodb-instance-${terraform.workspace}-${count.index}"
    Environment = terraform.workspace
  }
}

# Output the connection details
output "mongodb_endpoint" {
  value = aws_docdb_cluster.mongodb.endpoint
}

output "mongodb_port" {
  value = aws_docdb_cluster.mongodb.port
}

output "mongodb_connection_string" {
  value = "mongodb://${var.mongodb_username}:${var.mongodb_password}@${aws_docdb_cluster.mongodb.endpoint}:${aws_docdb_cluster.mongodb.port}/?ssl=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
  sensitive = true
}