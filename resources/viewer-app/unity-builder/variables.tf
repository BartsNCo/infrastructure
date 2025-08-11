variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "unity_builder_image_tag" {
  description = "Docker image tag for Unity builder"
  type        = string
  default     = "latest"
}

variable "unity_builder_cpu" {
  description = "CPU units for Unity builder ECS task (1024 = 1 vCPU)"
  type        = number
  default     = 8192
}

variable "unity_builder_memory" {
  description = "Memory in MB for Unity builder ECS task"
  type        = number
  default     = 16384
}

variable "unity_builder_ephemeral_storage" {
  description = "Ephemeral storage in GB for Unity builder ECS task"
  type        = number
  default     = 60
}

variable "github_token" {
  description = "GitHub personal access token for Unity repository access"
  type        = string
  sensitive   = true
}

variable "unity_username" {
  description = "Unity account username for license activation"
  type        = string
  sensitive   = true
}

variable "unity_password" {
  description = "Unity account password for license activation"
  type        = string
  sensitive   = true
}
