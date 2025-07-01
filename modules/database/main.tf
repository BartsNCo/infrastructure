# Security group for MongoDB (DocumentDB)
resource "aws_security_group" "mongodb" {
  name        = "${var.project_name}-mongodb-${var.environment}"
  description = "Security group for MongoDB DocumentDB cluster"
  vpc_id      = var.vpc_id

  # Allow access from jump server if it exists
  dynamic "ingress" {
    for_each = var.create_jumpserver ? [1] : []
    content {
      from_port       = 27017
      to_port         = 27017
      protocol        = "tcp"
      security_groups = [aws_security_group.jumpserver[0].id]
      description     = "MongoDB access from jump server"
    }
  }

  # Allow access from VPC CIDR blocks
  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # VPC CIDR - adjust as needed
    description = "MongoDB access from VPC"
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

# Secrets Manager secret for MongoDB connection string
resource "aws_secretsmanager_secret" "mongodb_connection" {
  name_prefix             = "${var.project_name}-mongodb-connection-${var.environment}"
  description             = "MongoDB connection string for ${var.project_name} ${var.environment}"
  recovery_window_in_days = 7

  tags = {
    Name        = "${var.project_name}-mongodb-connection-${var.environment}"
    Environment = var.environment
    Application = "${var.project_name}_${var.application_name}"
    Project     = var.project_name
  }
}

# Secrets Manager secret version with the connection string
resource "aws_secretsmanager_secret_version" "mongodb_connection" {
  secret_id = aws_secretsmanager_secret.mongodb_connection.id
  secret_string = jsonencode({
    MONGODB_URI = "mongodb://${urlencode(var.mongodb_username)}:${urlencode(var.mongodb_password)}@${aws_docdb_cluster.mongodb.endpoint}:${aws_docdb_cluster.mongodb.port}/?tls=true&tlsCAFile=/app/certs/global-bundle.pem&replicaSet=rs0&retryWrites=false"
  })
}

# Data source to find the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  count       = var.create_jumpserver ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security group for jump server
resource "aws_security_group" "jumpserver" {
  count       = var.create_jumpserver ? 1 : 0
  name        = "${var.project_name}-jumpserver-${var.environment}"
  description = "Security group for jump server to access DocumentDB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.project_name}-jumpserver-${var.environment}"
    Environment = var.environment
    Application = "${var.project_name}_${var.application_name}"
    Project     = var.project_name
  }
}

# Key pair for jump server
resource "aws_key_pair" "jumpserver" {
  count      = var.create_jumpserver && var.jumpserver_public_key != "" ? 1 : 0
  key_name   = "${var.project_name}-jumpserver-${var.environment}"
  public_key = var.jumpserver_public_key

  tags = {
    Name        = "${var.project_name}-jumpserver-key-${var.environment}"
    Environment = var.environment
    Application = "${var.project_name}_${var.application_name}"
    Project     = var.project_name
  }
}

# Jump server EC2 instance
resource "aws_instance" "jumpserver" {
  count                  = var.create_jumpserver ? 1 : 0
  ami                    = data.aws_ami.amazon_linux_2023[0].id
  instance_type          = var.jumpserver_instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.jumpserver[0].id]
  key_name               = var.jumpserver_public_key != "" ? aws_key_pair.jumpserver[0].key_name : null

  tags = {
    Name        = "${var.project_name}-jumpserver-${var.environment}"
    Environment = var.environment
    Application = "${var.project_name}_${var.application_name}"
    Project     = var.project_name
  }
}
