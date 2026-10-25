locals {
  # With IAM creation allowed we create EventBridge triggers, so polling is off.
  # With pre-existing roles (lab) EventBridge rules may be blocked, so poll.
  use_event_triggers = !var.use_existing_iam_roles
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = local.artifact_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_codepipeline" "svc" {
  for_each = local.services

  name          = "update-${each.key}-microservice"
  role_arn      = local.pipeline_role_arn
  pipeline_type = "V1"

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.artifacts.bucket
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        RepositoryName = aws_codecommit_repository.repo["deployment"].repository_name
        BranchName     = "dev"
        # CODE_ZIP, not a full clone: a full clone makes CodeDeployToECS fail
        # with "task definition file is missing".
        OutputArtifactFormat = "CODE_ZIP"
        PollForSourceChanges = local.use_event_triggers ? "false" : "true"
      }
    }

    action {
      name             = "Image"
      category         = "Source"
      owner            = "AWS"
      provider         = "ECR"
      version          = "1"
      output_artifacts = ["image-${each.key}"]

      configuration = {
        RepositoryName = aws_ecr_repository.repo[each.key].name
        ImageTag       = "latest"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name     = "Deploy"
      category = "Deploy"
      owner    = "AWS"
      provider = "CodeDeployToECS"
      version  = "1"
      # Both artifacts are required by CodeDeployToECS.
      input_artifacts = ["SourceArtifact", "image-${each.key}"]

      configuration = {
        ApplicationName                = aws_codedeploy_app.main.name
        DeploymentGroupName            = aws_codedeploy_deployment_group.svc[each.key].deployment_group_name
        TaskDefinitionTemplateArtifact = "SourceArtifact"
        TaskDefinitionTemplatePath     = "taskdef-${each.key}.json"
        AppSpecTemplateArtifact        = "SourceArtifact"
        AppSpecTemplatePath            = "appspec-${each.key}.yaml"
        Image1ArtifactName             = "image-${each.key}"
        Image1ContainerName            = "IMAGE1_NAME"
      }
    }
  }
}

# ---- EventBridge triggers (only when we may create IAM) -------------------
# Fire on `git push` to the deployment repo's dev branch...
resource "aws_cloudwatch_event_rule" "codecommit" {
  count = local.use_event_triggers ? 1 : 0

  name = "coffee-deployment-repo-dev-changed"

  event_pattern = jsonencode({
    source        = ["aws.codecommit"]
    "detail-type" = ["CodeCommit Repository State Change"]
    resources     = [aws_codecommit_repository.repo["deployment"].arn]
    detail = {
      event         = ["referenceCreated", "referenceUpdated"]
      referenceType = ["branch"]
      referenceName = ["dev"]
    }
  })
}

resource "aws_cloudwatch_event_target" "codecommit" {
  for_each = local.use_event_triggers ? local.services : {}

  rule     = aws_cloudwatch_event_rule.codecommit[0].name
  arn      = aws_codepipeline.svc[each.key].arn
  role_arn = aws_iam_role.events[0].arn
}

# ...and on `docker push` of :latest for each service's repository.
resource "aws_cloudwatch_event_rule" "ecr" {
  for_each = local.use_event_triggers ? local.services : {}

  name = "coffee-ecr-${each.key}-latest-pushed"

  event_pattern = jsonencode({
    source        = ["aws.ecr"]
    "detail-type" = ["ECR Image Action"]
    detail = {
      "action-type"     = ["PUSH"]
      result            = ["SUCCESS"]
      "repository-name" = [aws_ecr_repository.repo[each.key].name]
      "image-tag"       = ["latest"]
    }
  })
}

resource "aws_cloudwatch_event_target" "ecr" {
  for_each = local.use_event_triggers ? local.services : {}

  rule     = aws_cloudwatch_event_rule.ecr[each.key].name
  arn      = aws_codepipeline.svc[each.key].arn
  role_arn = aws_iam_role.events[0].arn
}
