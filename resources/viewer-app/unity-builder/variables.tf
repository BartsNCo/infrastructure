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

variable "task_cpu" {
  description = "CPU units for the ECS task"
  type        = string
  default     = "2048"
}

variable "task_memory" {
  description = "Memory for the ECS task in MB"
  type        = string
  default     = "4096"
}