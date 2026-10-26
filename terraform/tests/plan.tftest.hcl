# Offline plan checks (no AWS calls). Requires Terraform >= 1.7: `terraform test`

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_availability_zones" {
    defaults = { names = ["us-east-1a", "us-east-1b", "us-east-1c"] }
  }
  mock_data "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/Mock" }
  }
}

run "standalone_mode" {
  command = plan

  variables {
    use_existing_vpc       = false
    use_existing_iam_roles = false
    create_rds             = true
    create_cloud9          = true
    db_password            = "Passw0rd123"
    admin_allowed_cidr     = "203.0.113.25/32"
  }

  assert {
    condition     = length(aws_lb_target_group.tg) == 4
    error_message = "expected 4 target groups"
  }
  assert {
    condition     = length(aws_cloudwatch_event_rule.ecr) == 2 && length(aws_cloudwatch_event_rule.codecommit) == 1
    error_message = "EventBridge triggers expected in standalone mode"
  }
  assert {
    condition     = aws_codepipeline.svc["employee"].stage[0].action[0].configuration["PollForSourceChanges"] == "false"
    error_message = "polling should be off when EventBridge triggers exist"
  }
  assert {
    condition     = length(aws_lb_listener_rule.admin_prod.condition) == 2
    error_message = "admin rule should have path + source_ip conditions"
  }
  assert {
    condition     = strcontains(templatefile("${path.module}/templates/taskdef.json.tftpl", { family = "f", container_name = "customer", execution_role_arn = "arn", db_endpoint = "db", log_group = "g", region = "r" }), "\"image\": \"<IMAGE1_NAME>\"")
    error_message = "taskdef must keep the literal <IMAGE1_NAME> placeholder"
  }
  assert {
    condition     = strcontains(templatefile("${path.module}/templates/appspec.yaml.tftpl", { container_name = "employee" }), "TaskDefinition: <TASK_DEFINITION>")
    error_message = "appspec must keep the literal <TASK_DEFINITION> placeholder"
  }
}

run "lab_mode" {
  command = plan

  variables {
    use_existing_vpc       = true
    use_existing_iam_roles = true
    create_rds             = false
    db_endpoint            = "db.example.internal"
  }

  assert {
    condition     = length(aws_iam_role.pipeline) == 0 && length(aws_vpc.main) == 0 && length(aws_db_instance.main) == 0
    error_message = "lab mode must not create VPC, roles or RDS"
  }
  assert {
    condition     = length(aws_cloudwatch_event_rule.ecr) == 0
    error_message = "no EventBridge rules in lab mode"
  }
  assert {
    condition     = aws_codepipeline.svc["customer"].stage[0].action[0].configuration["PollForSourceChanges"] == "true"
    error_message = "lab mode should poll CodeCommit"
  }
  assert {
    condition     = length(aws_lb_listener_rule.admin_test.condition) == 1
    error_message = "no source_ip condition when admin_allowed_cidr is empty"
  }
}

run "rds_requires_password" {
  command = plan

  variables {
    use_existing_vpc       = false
    use_existing_iam_roles = false
    create_rds             = true
    db_password            = ""
  }

  expect_failures = [terraform_data.db_input_check]
}
