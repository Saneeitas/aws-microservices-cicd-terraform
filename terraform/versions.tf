terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  # State is local by default. For team use, switch to an S3 backend:
  # backend "s3" {
  #   bucket = "<your-state-bucket>"
  #   key    = "coffee-microservices/terraform.tfstate"
  #   region = "us-east-1"
  # }
}
