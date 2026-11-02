terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Bootstrap uses LOCAL state on purpose: it creates the bucket that main/ stores its state in.
# Applied once, by hand. Keep terraform.tfstate safe (it is git-ignored) or migrate it into the
# state bucket afterwards with `terraform init -migrate-state` and a backend block.
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
