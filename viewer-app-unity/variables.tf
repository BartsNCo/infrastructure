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

variable "application_name" {
  description = "Application name"
  type        = string
  default     = "viewer-unity"
}