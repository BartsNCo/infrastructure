# ECS Cluster configuration

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}_viewer_cluster_${terraform.workspace}"

  dynamic "setting" {
    for_each = var.enable_container_insights ? [1] : []
    content {
      name  = "containerInsights"
      value = "enabled"
    }
  }

  tags = {
    Name        = "${var.project_name}_viewer_app_${terraform.workspace}"
    Environment = terraform.workspace
    Project     = var.project_name
    Application = "viewer-app"
  }
}
