# Input variables for viewer-app-database
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile"
  type        = string
  default     = "barts-admin"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "barts"
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

variable "public_key" {
  description = "SSH public key for jump server access"
  type        = string
  default     = ""
}
