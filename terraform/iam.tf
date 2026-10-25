# Created only when use_existing_iam_roles = false.
# Names match the lab roles so the rest of the config is mode-agnostic.

# ---- PipelineRole --------------------------------------------------------
# Used by CodePipeline AND as the ECS task execution role (the lab does the
# same), so it trusts both services.
resource "aws_iam_role" "pipeline" {
  count = var.use_existing_iam_roles ? 0 : 1
  name  = "PipelineRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = ["codepipeline.amazonaws.com", "ecs-tasks.amazonaws.com"] }
    }]
  })
}

# Task execution: pull from ECR, write to CloudWatch Logs.
resource "aws_iam_role_policy_attachment" "pipeline_task_execution" {
  count      = var.use_existing_iam_roles ? 0 : 1
  role       = aws_iam_role.pipeline[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "pipeline" {
  count = var.use_existing_iam_roles ? 0 : 1
  name  = "pipeline-access"
  role  = aws_iam_role.pipeline[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CodeCommitSource"
        Effect = "Allow"
        Action = [
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetRepository",
          "codecommit:UploadArchive",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:CancelUploadArchive",
        ]
        Resource = "arn:aws:codecommit:${var.aws_region}:${local.account_id}:*"
      },
      {
        Sid      = "EcrSource"
        Effect   = "Allow"
        Action   = ["ecr:DescribeImages"]
        Resource = "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/*"
      },
      {
        Sid    = "ArtifactBucket"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:GetBucketVersioning", "s3:GetBucketLocation"]
        Resource = [
          "arn:aws:s3:::${local.artifact_bucket_name}",
          "arn:aws:s3:::${local.artifact_bucket_name}/*",
        ]
      },
      {
        Sid    = "CodeDeployToEcs"
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision",
        ]
        Resource = "*"
      },
      {
        Sid      = "EcsTaskDefinition"
        Effect   = "Allow"
        Action   = ["ecs:RegisterTaskDefinition", "ecs:DescribeTaskDefinition", "ecs:DescribeServices", "ecs:UpdateService"]
        Resource = "*"
      },
      {
        # CodeDeployToEcs registers a task definition that names this role as execution role.
        Sid      = "PassRoleToEcs"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "*"
        Condition = {
          StringEqualsIfExists = { "iam:PassedToService" = ["ecs-tasks.amazonaws.com"] }
        }
      },
    ]
  })
}

# ---- DeployRole (CodeDeploy service role for ECS blue/green) -------------
resource "aws_iam_role" "deploy" {
  count = var.use_existing_iam_roles ? 0 : 1
  name  = "DeployRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "codedeploy.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "deploy" {
  count      = var.use_existing_iam_roles ? 0 : 1
  role       = aws_iam_role.deploy[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# ---- EventBridge role (starts pipelines on CodeCommit / ECR events) ------
resource "aws_iam_role" "events" {
  count = var.use_existing_iam_roles ? 0 : 1
  name  = "coffee-events-start-pipeline"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "events.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "events" {
  count = var.use_existing_iam_roles ? 0 : 1
  name  = "start-pipelines"
  role  = aws_iam_role.events[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "codepipeline:StartPipelineExecution"
      Resource = "arn:aws:codepipeline:${var.aws_region}:${local.account_id}:update-*-microservice"
    }]
  })
}
