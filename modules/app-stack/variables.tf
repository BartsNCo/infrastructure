variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "application_name" {
  description = "Application name (e.g., frontend, backend)"
  type        = string
}

variable "application_description" {
  description = "Elastic Beanstalk application description"
  type        = string
  default     = ""
}

variable "environments" {
  description = "Map of environments to create"
  type = map(object({
    description         = string
    solution_stack_name = string
    tier                = string # WebServer or Worker
    settings = list(object({
      namespace = string
      name      = string
      value     = string
    }))
  }))
}

variable "instance_type" {
  description = "EC2 instance type for Elastic Beanstalk environments"
  type        = string
  default     = "t3.micro"
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}