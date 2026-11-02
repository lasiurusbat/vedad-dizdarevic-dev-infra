variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-central-1"
}

variable "state_bucket_name" {
  description = "Globally unique name for the Terraform state bucket, e.g. vdd-tfstate-<account-id>."
  type        = string
}

variable "site_bucket_name" {
  description = "Name of the site bucket created by main/. Needed here to scope the app deploy role. Must match main's var.site_bucket_name."
  type        = string
}

variable "github_org" {
  description = "GitHub organisation (or user) that owns both repos."
  type        = string
}

variable "app_repo" {
  description = "Name of the app repo (without the org)."
  type        = string
}

variable "infra_repo" {
  description = "Name of the infra repo (without the org)."
  type        = string
}

variable "infra_apply_environment" {
  description = "GitHub Actions environment the infra apply job runs in. Jobs using an environment get an OIDC subject of repo:<org>/<repo>:environment:<name> instead of ...:ref:..., so both are trusted."
  type        = string
  default     = "production"
}
