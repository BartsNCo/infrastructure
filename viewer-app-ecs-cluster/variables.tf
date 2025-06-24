# Input variables for ECS cluster

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "barts"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile to use"
  type        = string
  default     = "barts-admin"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for the cluster"
  type        = bool
  default     = true
}