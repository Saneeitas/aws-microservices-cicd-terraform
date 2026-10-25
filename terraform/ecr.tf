resource "aws_ecr_repository" "repo" {
  for_each = local.services

  name         = each.key
  force_delete = true # lets `terraform destroy` remove repos that still hold images

  image_scanning_configuration {
    scan_on_push = true
  }
}

# The lab allows Principal "*". The account root is equivalent for same-account
# IAM principals and avoids a public-looking policy.
resource "aws_ecr_repository_policy" "repo" {
  for_each   = aws_ecr_repository.repo
  repository = each.value.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AccountFullAccess"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
      Action    = "ecr:*"
    }]
  })
}
