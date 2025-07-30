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
