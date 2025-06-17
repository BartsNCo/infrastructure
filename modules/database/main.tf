# Security group for MongoDB (DocumentDB)
resource "aws_security_group" "mongodb" {
  name        = "${var.project_name}-mongodb-${var.environment}"
  description = "Security group for MongoDB DocumentDB cluster"
  vpc_id      = var.vpc_id

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
    Name        = "${var.project_name}-mongodb-${var.environment}"
    Environment = var.environment
    Application = "${var.project_name}_${var.application_name}"
    Project     = var.project_name
  }
}

# Subnet group for DocumentDB
resource "aws_docdb_subnet_group" "mongodb" {
  name       = "${var.project_name}-mongodb-${var.environment}"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "${var.project_name}-mongodb-subnet-group-${var.environment}"
    Environment = var.environment
    Application = "${var.project_name}_${var.application_name}"
    Project     = var.project_name
  }
}

# DocumentDB cluster (AWS managed MongoDB-compatible)
resource "aws_docdb_cluster" "mongodb" {
  cluster_identifier      = "${var.project_name}-mongodb-${var.environment}"
  engine                  = "docdb"
  master_username         = var.mongodb_username
  master_password         = var.mongodb_password
  backup_retention_period = var.backup_retention_period
  preferred_backup_window = var.preferred_backup_window
  skip_final_snapshot     = var.skip_final_snapshot
  db_subnet_group_name    = aws_docdb_subnet_group.mongodb.name
  vpc_security_group_ids  = [aws_security_group.mongodb.id]

  tags = {
    Name        = "${var.project_name}-mongodb-${var.environment}"
    Environment = var.environment
    Application = "${var.project_name}_${var.application_name}"
    Project     = var.project_name
  }
}

# DocumentDB cluster instance
resource "aws_docdb_cluster_instance" "mongodb" {
  count              = 1
  identifier         = "${var.project_name}-mongodb-${var.environment}-${count.index}"
  cluster_identifier = aws_docdb_cluster.mongodb.id
  instance_class     = var.instance_class

  tags = {
    Name        = "${var.project_name}-mongodb-instance-${var.environment}-${count.index}"
    Environment = var.environment
    Application = "${var.project_name}_${var.application_name}"
    Project     = var.project_name
  }
}