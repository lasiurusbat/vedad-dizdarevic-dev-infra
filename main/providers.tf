provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "vedad-dizdarevic.dev"
      Stack     = "main"
      ManagedBy = "terraform"
    }
  }
}

# Reads CLOUDFLARE_API_TOKEN from the environment.
provider "cloudflare" {}
