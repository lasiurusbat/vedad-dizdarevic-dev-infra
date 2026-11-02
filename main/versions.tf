terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  # Bucket is passed at init time so it is not hard-coded here:
  #   terraform init -backend-config=backend.hcl
  backend "s3" {
    key          = "main/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true # native S3 locking, no DynamoDB table
  }
}
