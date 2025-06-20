# Input variables for ecs-service module

variable "project_name" {
  description = "Name prefix for resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "application_name" {
  description = "Application name for the service"
  type        = string
}

variable "cluster_id" {
  description = "ECS cluster ID where the service will run"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for networking resources"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the service"
  type        = list(string)
}

variable "container_definitions" {
  description = "Container definitions configuration"
  type = object({
    name  = string
    image = optional(string, "")
    environment_variables = optional(list(object({
      name  = string
      value = string
    })), [])
    secrets = optional(list(object({
      secret_manager_arn = string
      key                = string
    })), [])
  })
}

variable "docker_image" {
  description = "Docker image to use for the container"
  type        = string
  default     = "public.ecr.aws/docker/library/busybox:latest"
}

variable "container_port" {
  description = "Port that the container listens on"
  type        = number
  default     = 80
}

variable "cpu" {
  description = "CPU units for the task (256, 512, 1024, etc.)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory in MiB for the task"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "health_check_path" {
  description = "Health check path for the load balancer"
  type        = string
  default     = "/health"
}

variable "s3_bucket_names" {
  description = "List of S3 bucket names that the ECS service needs access to"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}