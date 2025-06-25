variable "secret_name" {
  description = "Name of the secret"
  type        = string
}

variable "description" {
  description = "Description of the secret"
  type        = string
  default     = ""
}

variable "secret_type" {
  description = "Type of secret - 'string' for plain text or 'json' for structured data"
  type        = string
  default     = "json"
  validation {
    condition     = contains(["string", "json"], var.secret_type)
    error_message = "Secret type must be either 'string' or 'json'"
  }
}

variable "secret_string" {
  description = "The secret string (use when secret_type is 'string')"
  type        = string
  default     = null
  sensitive   = true
}

variable "secret_data" {
  description = "The secret data as a map (use when secret_type is 'json')"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "kms_key_id" {
  description = "KMS key ID to use for encryption (optional)"
  type        = string
  default     = null
}

variable "recovery_window_days" {
  description = "Number of days that AWS Secrets Manager waits before it can delete the secret"
  type        = number
  default     = 30
}

variable "enable_rotation" {
  description = "Enable automatic rotation for this secret"
  type        = bool
  default     = false
}

variable "rotation_days" {
  description = "Number of days between automatic scheduled rotations"
  type        = number
  default     = 30
}

variable "rotation_lambda_arn" {
  description = "ARN of the Lambda function that can rotate the secret"
  type        = string
  default     = null
}

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
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "read_groups" {
  description = "List of IAM groups to attach the read-only policy to"
  type        = list(string)
  default     = []
}

variable "readwrite_groups" {
  description = "List of IAM groups to attach the read-write policy to"
  type        = list(string)
  default     = []
}

variable "read_users" {
  description = "List of IAM users to attach the read-only policy to"
  type        = list(string)
  default     = []
}

variable "readwrite_users" {
  description = "List of IAM users to attach the read-write policy to"
  type        = list(string)
  default     = []
}