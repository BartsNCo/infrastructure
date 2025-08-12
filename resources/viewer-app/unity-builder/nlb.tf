# Network Load Balancer for SSH access
resource "aws_lb" "unity_builder_ssh" {
  name               = "${local.short_workspace}-unity-ssh-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = data.aws_subnets.default.ids

  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${terraform.workspace}-unity-builder-ssh-nlb"
  }
}

# Target group for SSH
resource "aws_lb_target_group" "unity_builder_ssh" {
  name     = "${local.short_workspace}-unity-ssh-tg"
  port     = 22
  protocol = "TCP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "22"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${terraform.workspace}-unity-builder-ssh-tg"
  }
}

# Attach EC2 instance to target group
resource "aws_lb_target_group_attachment" "unity_builder_ssh" {
  target_group_arn = aws_lb_target_group.unity_builder_ssh.arn
  target_id        = aws_instance.unity_builder.id
  port             = 22
}

# Listener for SSH traffic
resource "aws_lb_listener" "unity_builder_ssh" {
  load_balancer_arn = aws_lb.unity_builder_ssh.arn
  port              = "22"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.unity_builder_ssh.arn
  }
}

# Route53 record for SSH subdomain
resource "aws_route53_record" "unity_builder_ssh" {
  zone_id = data.terraform_remote_state.route53.outputs.hosted_zone_id[terraform.workspace]
  name    = "unity-builder-ssh.${data.terraform_remote_state.route53.outputs.domains_name[terraform.workspace]}"
  type    = "A"

  alias {
    name                   = aws_lb.unity_builder_ssh.dns_name
    zone_id                = aws_lb.unity_builder_ssh.zone_id
    evaluate_target_health = true
  }
}