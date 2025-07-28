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

variable "domain_name" {
  description = "The domain name for the hosted zone"
  type        = string
  default     = "bartsnco.com.br"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "barts"
}

variable "subdomain" {
  type = list(map(string))
}
