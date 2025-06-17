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
  default     = "s3unity"
}

variable "allow_direct_s3_access" {
  description = "Allow direct public access to S3 bucket objects"
  type        = bool
  default     = false
}