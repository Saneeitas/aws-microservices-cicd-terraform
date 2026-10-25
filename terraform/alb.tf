locals {
  # Blue/green pairs: CodeDeploy swaps traffic between "one" and "two".
  target_groups = {
    for pair in setproduct(keys(local.services), ["one", "two"]) :
    "${pair[0]}-tg-${pair[1]}" => {
      service = pair[0]
      path    = local.services[pair[0]].health_check_path
    }
  }

  restrict_admin = var.admin_allowed_cidr != ""
}

resource "aws_lb_target_group" "tg" {
  for_each = local.target_groups

  name        = each.key
  target_type = "ip" # required for Fargate awsvpc tasks
  protocol    = "HTTP"
  port        = 8080
  vpc_id      = local.vpc_id

  health_check {
    path = each.value.path
  }
}

resource "aws_lb" "main" {
  name               = "microservicesLB"
  load_balancer_type = "application"
  internal           = false
  ip_address_type    = "ipv4"
  subnets            = local.public_subnet_ids
  security_groups    = [aws_security_group.microservices.id]
}

# Port 80 = production traffic (starts on the "-two" groups).
# Port 8080 = CodeDeploy test traffic (starts on the "-one" groups).
resource "aws_lb_listener" "prod" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg["customer-tg-two"].arn
  }

  lifecycle {
    # CodeDeploy rewrites the default action to the active target group on every deployment.
    ignore_changes = [default_action]
  }
}

resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg["customer-tg-one"].arn
  }

  lifecycle {
    # CodeDeploy rewrites the default action during deployments.
    ignore_changes = [default_action]
  }
}

resource "aws_lb_listener_rule" "admin_prod" {
  listener_arn = aws_lb_listener.prod.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg["employee-tg-two"].arn
  }

  condition {
    path_pattern {
      values = ["/admin/*"]
    }
  }

  dynamic "condition" {
    for_each = local.restrict_admin ? [var.admin_allowed_cidr] : []
    content {
      source_ip {
        values = [condition.value]
      }
    }
  }

  lifecycle {
    # CodeDeploy repoints this rule's target group during deployments.
    ignore_changes = [action]
  }
}

resource "aws_lb_listener_rule" "admin_test" {
  listener_arn = aws_lb_listener.test.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg["employee-tg-one"].arn
  }

  condition {
    path_pattern {
      values = ["/admin/*"]
    }
  }

  dynamic "condition" {
    for_each = local.restrict_admin ? [var.admin_allowed_cidr] : []
    content {
      source_ip {
        values = [condition.value]
      }
    }
  }

  lifecycle {
    # CodeDeploy repoints this rule's target group during deployments.
    ignore_changes = [action]
  }
}
