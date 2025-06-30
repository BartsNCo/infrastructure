variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "application_name" {
  description = "Application name"
  type        = string
  default     = "database"
}

variable "mongodb_username" {
  description = "MongoDB master username"
  type        = string
  sensitive   = true
}

variable "mongodb_password" {
  description = "MongoDB master password"
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "VPC ID where database will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for database subnet group"
  type        = list(string)
}

variable "instance_class" {
  description = "DocumentDB instance class"
  type        = string
  default     = "t3.medium"
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 1
}

variable "preferred_backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "07:00-09:00"
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when deleting cluster"
  type        = bool
  default     = true
}

variable "create_jumpserver" {
  description = "Whether to create a jump server for SSH tunneling to the database"
  type        = bool
  default     = false
}

variable "jumpserver_public_key" {
  description = "SSH public key that can access the jump server"
  type        = string
  default     = ""
}

variable "jumpserver_instance_type" {
  description = "EC2 instance type for the jump server"
  type        = string
  default     = "t3.micro"
}
