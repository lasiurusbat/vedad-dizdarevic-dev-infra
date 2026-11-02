# Non-secret values only. Copy the ones marked "app repo" into the app repo's Actions variables.

output "site_bucket" {
  description = "App repo variable: S3_BUCKET."
  value       = aws_s3_bucket.site.id
}

output "app_deploy_role_arn" {
  description = "App repo variable: AWS_DEPLOY_ROLE_ARN."
  value       = data.aws_iam_role.app_deploy.arn
}

output "key_rotation_role_arn" {
  description = "App repo variable for the rotation workflow."
  value       = aws_iam_role.key_rotation.arn
}

output "cloudflare_zone_id" {
  description = "App repo variable: CLOUDFLARE_ZONE_ID (cache purge)."
  value       = cloudflare_zone.site.id
}

output "name_servers" {
  description = "Set these as the domain's nameservers at the registrar."
  value       = cloudflare_zone.site.name_servers
}

output "worker_iam_user" {
  description = "Create its access key by hand and store it with `wrangler secret put`."
  value       = aws_iam_user.worker.name
}

output "contact_function_name" {
  value = aws_lambda_function.contact.function_name
}

output "contact_function_url" {
  description = "Worker config (not secret; AWS_IAM auth rejects unsigned calls)."
  value       = aws_lambda_function_url.contact.function_url
}

output "turnstile_site_key" {
  description = "Public site key for the site build."
  value       = cloudflare_turnstile_widget.contact.sitekey
}
