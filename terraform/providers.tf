provider "aws" {
  region = var.aws_region

  # Applies Project tag to every taggable resource (rule 6).
  default_tags {
    tags = {
      Project = "coffee-microservices"
    }
  }
}
