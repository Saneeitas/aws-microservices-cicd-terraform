resource "aws_codedeploy_app" "main" {
  name             = "microservices"
  compute_platform = "ECS"
}

resource "aws_codedeploy_deployment_group" "svc" {
  for_each = local.services

  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "microservices-${each.key}"
  service_role_arn       = local.deploy_role_arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.svc[each.key].name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.prod.arn]
      }

      test_traffic_route {
        listener_arns = [aws_lb_listener.test.arn]
      }

      # Order matters: "-two" is the initial production group.
      target_group {
        name = aws_lb_target_group.tg["${each.key}-tg-two"].name
      }

      target_group {
        name = aws_lb_target_group.tg["${each.key}-tg-one"].name
      }
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}
