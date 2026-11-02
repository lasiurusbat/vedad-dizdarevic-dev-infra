terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Bootstrap was first applied with LOCAL state (it creates this bucket), then migrated here:
  #   terraform init -migrate-state -backend-config=backend.hcl
  backend "s3" {
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "vedad-dizdarevic.dev"
      Stack     = "bootstrap"
      ManagedBy = "terraform"
    }
  }
}
