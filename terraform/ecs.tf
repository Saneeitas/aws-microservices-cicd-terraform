# Fargate-only cluster: no EC2 capacity providers.
resource "aws_ecs_cluster" "main" {
  name = "microservices-serverlesscluster"
}

resource "aws_ecs_task_definition" "svc" {
  for_each = local.services

  family                   = "${each.key}-microservice"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"

  # The lab reuses PipelineRole as the execution role (it can pull from ECR and
  # write logs). Same here so both modes behave identically.
  execution_role_arn = local.pipeline_role_arn

  container_definitions = jsonencode([{
    name      = each.key
    image     = "${aws_ecr_repository.repo[each.key].repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]

    environment = [{
      name  = "APP_DB_HOST"
      value = local.db_endpoint
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "awslogs-capstone"
      }
    }
  }])
}

resource "aws_ecs_service" "svc" {
  for_each = local.services

  name                = "${each.key}-microservice"
  cluster             = aws_ecs_cluster.main.id
  task_definition     = aws_ecs_task_definition.svc[each.key].arn
  launch_type         = "FARGATE"
  scheduling_strategy = "REPLICA"
  desired_count       = each.value.desired_count

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  # First deployment starts on the "-two" (production) group.
  load_balancer {
    target_group_arn = aws_lb_target_group.tg["${each.key}-tg-two"].arn
    container_name   = each.key
    container_port   = 8080
  }

  network_configuration {
    subnets          = local.public_subnet_ids
    security_groups  = [aws_security_group.microservices.id]
    assign_public_ip = true # public subnets, no NAT gateway
  }

  # The target group must be attached to a listener before the service can be
  # created; the image must exist before tasks start.
  depends_on = [
    aws_lb_listener.prod,
    aws_lb_listener.test,
    aws_lb_listener_rule.admin_prod,
    aws_lb_listener_rule.admin_test,
    null_resource.image,
  ]

  lifecycle {
    # With the CODE_DEPLOY controller, CodeDeploy owns the task definition and
    # the active target group after each deployment. desired_count is ignored
    # so scaling (console/CLI/autoscaling) is not reverted by Terraform;
    # change it via `aws ecs update-service` or the first apply.
    ignore_changes = [task_definition, load_balancer, desired_count]
  }
}

# desired_count is in ignore_changes above (so CodeDeploy/autoscaling are not
# fought), which means editing customer_desired_count would be a no-op. This
# re-applies the count via the ECS API only when the variable changes, so
# `make apply` still scales and the pipeline is not triggered.
resource "terraform_data" "scale" {
  for_each = local.services

  triggers_replace = [each.value.desired_count]

  provisioner "local-exec" {
    command = "aws ecs update-service --region ${var.aws_region} --cluster ${aws_ecs_cluster.main.name} --service ${aws_ecs_service.svc[each.key].name} --desired-count ${each.value.desired_count} --no-cli-pager > /dev/null"
  }
}
