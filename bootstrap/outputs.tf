output "state_bucket" {
  description = "Put this in main/backend.hcl."
  value       = aws_s3_bucket.state.id
}

output "region" {
  value = var.region
}

output "github_oidc_provider_arn" {
  value = data.aws_iam_openid_connect_provider.github.arn
}

output "infra_apply_role_arn" {
  description = "Infra repo Actions variable (AWS_APPLY_ROLE_ARN)."
  value       = aws_iam_role.infra_apply.arn
}

output "infra_plan_role_arn" {
  description = "Infra repo Actions variable (AWS_PLAN_ROLE_ARN)."
  value       = aws_iam_role.infra_plan.arn
}

output "app_deploy_role_arn" {
  description = "App repo Actions variable (AWS_DEPLOY_ROLE_ARN)."
  value       = aws_iam_role.app_deploy.arn
}
