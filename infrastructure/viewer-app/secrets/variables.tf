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
  default     = "viewer"
}

variable "secrets" {
  description = "Map of secrets to create"
  type = map(object({
    description     = string
    data            = map(string)
    enable_rotation = optional(bool, false)
    rotation_days   = optional(number, 30)
  }))
  default = {
    database-credentials = {
      description = "MongoDB database credentials"
      data = {
        username = "placeholder"
        password = "placeholder"
      }
    }
    api-keys = {
      description = "External API keys"
      data = {
        google_maps_api_key = "placeholder"
        aws_access_key_id   = "placeholder"
        aws_secret_key      = "placeholder"
      }
    }
    jwt-secrets = {
      description = "JWT signing secrets"
      data = {
        jwt_secret         = "placeholder"
        jwt_refresh_secret = "placeholder"
      }
    }
  }
}

variable "recovery_window_days" {
  description = "Number of days that AWS Secrets Manager waits before it can delete the secret"
  type        = number
  default     = 30
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
