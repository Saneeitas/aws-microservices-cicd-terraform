data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# ---- Existing VPC (lab mode) ---------------------------------------------

data "aws_vpc" "lab" {
  count = var.use_existing_vpc ? 1 : 0

  tags = {
    Name = "LabVPC"
  }
}

data "aws_subnet" "public_1" {
  count  = var.use_existing_vpc ? 1 : 0
  vpc_id = data.aws_vpc.lab[0].id

  tags = {
    Name = "Public Subnet 1"
  }
}

data "aws_subnet" "public_2" {
  count  = var.use_existing_vpc ? 1 : 0
  vpc_id = data.aws_vpc.lab[0].id

  tags = {
    Name = "Public Subnet 2"
  }
}

# ---- Existing IAM roles (lab mode) ---------------------------------------

data "aws_iam_role" "pipeline" {
  count = var.use_existing_iam_roles ? 1 : 0
  name  = "PipelineRole"
}

data "aws_iam_role" "deploy" {
  count = var.use_existing_iam_roles ? 1 : 0
  name  = "DeployRole"
}

# ---- Unified locals: the rest of the config uses only these --------------

locals {
  account_id = data.aws_caller_identity.current.account_id

  vpc_id = var.use_existing_vpc ? data.aws_vpc.lab[0].id : aws_vpc.main[0].id

  public_subnet_ids = var.use_existing_vpc ? [
    data.aws_subnet.public_1[0].id,
    data.aws_subnet.public_2[0].id,
    ] : [
    aws_subnet.public[0].id,
    aws_subnet.public[1].id,
  ]

  pipeline_role_arn = var.use_existing_iam_roles ? data.aws_iam_role.pipeline[0].arn : aws_iam_role.pipeline[0].arn
  deploy_role_arn   = var.use_existing_iam_roles ? data.aws_iam_role.deploy[0].arn : aws_iam_role.deploy[0].arn

  # Single source of truth for the two microservices (for_each everywhere).
  services = {
    customer = {
      health_check_path = "/"
      desired_count     = var.customer_desired_count
    }
    employee = {
      health_check_path = "/admin/suppliers"
      desired_count     = 1
    }
  }

  # Name is fixed here so the pipeline role policy can reference it before the bucket exists.
  artifact_bucket_name = "coffee-pipeline-artifacts-${local.account_id}-${var.aws_region}"
}
