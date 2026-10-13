# ========================================
# Target Group Module
# ========================================

resource "aws_lb_target_group" "this" {
  name     = "${var.project_name}-${var.name}-tg"
  port     = var.port
  protocol = var.protocol
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = var.health_check_port
    protocol            = var.health_check_protocol
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    matcher             = var.health_check_matcher
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.name}-tg"
  })
}

# Attach instances to target group
resource "aws_lb_target_group_attachment" "this" {
  count            = length(var.target_ids)
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = var.target_ids[count.index]
  port             = var.port
}
