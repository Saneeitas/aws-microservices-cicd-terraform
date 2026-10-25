# NOTE: AWS has closed CodeCommit to new customers; this works only in accounts
# that already use it.
resource "aws_codecommit_repository" "repo" {
  for_each = toset(["microservices", "deployment"])

  repository_name = each.key
  description     = each.key == "deployment" ? "Task definitions and AppSpec files" : "Application source code"
}

# The aws provider has no aws_codecommit_file resource (checked v5.100), so the
# files are rendered locally and pushed by scripts/push_deployment_files.sh.
#
# <IMAGE1_NAME> and <TASK_DEFINITION> contain no "${", so templatefile leaves
# them literal; CodeDeploy substitutes them at deploy time.
resource "local_file" "taskdef" {
  for_each = local.services

  filename = "${path.module}/../deployment/taskdef-${each.key}.json"
  content = templatefile("${path.module}/templates/taskdef.json.tftpl", {
    family             = "${each.key}-microservice"
    container_name     = each.key
    execution_role_arn = local.pipeline_role_arn
    db_endpoint        = local.db_endpoint
    log_group          = aws_cloudwatch_log_group.app.name
    region             = var.aws_region
  })
}

resource "local_file" "appspec" {
  for_each = local.services

  filename = "${path.module}/../deployment/appspec-${each.key}.yaml"
  content = templatefile("${path.module}/templates/appspec.yaml.tftpl", {
    container_name = each.key
  })
}
