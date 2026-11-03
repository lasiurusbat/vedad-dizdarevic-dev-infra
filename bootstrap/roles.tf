data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  # Everything main/ creates in IAM is named vdd-*, which is what the apply role is scoped to.
  # The bootstrap roles below are named gh-*, so the apply role cannot modify them.
  iam_prefix = "vdd-"
}

# ---------------------------------------------------------------------------------------------
# App repo, main branch: deploy role. Writes to the site bucket only, no access to Terraform state.
# ---------------------------------------------------------------------------------------------
resource "aws_iam_role" "app_deploy" {
  name                 = "gh-app-deploy"
  assume_role_policy   = data.aws_iam_policy_document.trust_app_deploy.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "app_deploy" {
  statement {
    sid       = "ListSiteBucket"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = ["arn:aws:s3:::${var.site_bucket_name}"]
  }

  statement {
    sid       = "WriteSiteObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.site_bucket_name}/*"]
  }
}

resource "aws_iam_role_policy" "app_deploy" {
  name   = "site-bucket-write"
  role   = aws_iam_role.app_deploy.id
  policy = data.aws_iam_policy_document.app_deploy.json
}

# ---------------------------------------------------------------------------------------------
# Infra repo, pull requests: plan-only role (read everything, write only state lock files).
# ---------------------------------------------------------------------------------------------
resource "aws_iam_role" "infra_plan" {
  name                 = "gh-infra-plan"
  assume_role_policy   = data.aws_iam_policy_document.trust_infra_plan.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "infra_plan_readonly" {
  role       = aws_iam_role.infra_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "infra_plan_state" {
  statement {
    sid       = "ListState"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }

  # use_lockfile = true writes <key>.tflock next to the state object, even for `plan`.
  statement {
    sid       = "LockState"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "infra_plan_state" {
  name   = "state-read-and-lock"
  role   = aws_iam_role.infra_plan.id
  policy = data.aws_iam_policy_document.infra_plan_state.json
}

# ---------------------------------------------------------------------------------------------
# Infra repo, main branch / production environment: apply role for main/.
# Scoped by service and by resource name prefix; not AdministratorAccess.
# ---------------------------------------------------------------------------------------------
resource "aws_iam_role" "infra_apply" {
  name                 = "gh-infra-apply"
  assume_role_policy   = data.aws_iam_policy_document.trust_infra_apply.json
  max_session_duration = 3600
}

# The apply role manages Terraform for this project: S3 on the site bucket, IAM only on vdd-* names, trusted only from main or the production environment. Narrowing further is tracked as a permissions-boundary hardening task
#trivy:ignore:AWS-0345
data "aws_iam_policy_document" "infra_apply" {
  #checkov:skip=CKV_AWS_111:The apply role manages Terraform for this project: S3 on the site bucket, IAM only on vdd-* names, trusted only from main or the production environment. Narrowing further is tracked as a permissions-boundary hardening task
  #checkov:skip=CKV_AWS_109:The apply role manages Terraform for this project: S3 on the site bucket, IAM only on vdd-* names, trusted only from main or the production environment. Narrowing further is tracked as a permissions-boundary hardening task
  #checkov:skip=CKV_AWS_356:The apply role manages Terraform for this project: S3 on the site bucket, IAM only on vdd-* names, trusted only from main or the production environment. Narrowing further is tracked as a permissions-boundary hardening task
  statement {
    sid       = "ListState"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid       = "ReadWriteState"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }

  statement {
    sid     = "SiteBucket"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${var.site_bucket_name}",
      "arn:aws:s3:::${var.site_bucket_name}/*",
    ]
  }

  # IAM is limited to vdd-* names. Roles/users/policies outside that prefix (including the
  # gh-* roles above) cannot be created or changed by this role.
  statement {
    sid     = "ManageOwnIam"
    actions = ["iam:*"]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${local.iam_prefix}*",
      "arn:aws:iam::${local.account_id}:user/${local.iam_prefix}*",
      "arn:aws:iam::${local.account_id}:user/service/${local.iam_prefix}*", # the Worker user lives under /service/
      "arn:aws:iam::${local.account_id}:policy/${local.iam_prefix}*",
    ]
  }

  # Read-only lookups main/ performs on bootstrap-owned objects.
  statement {
    sid     = "ReadBootstrapIam"
    actions = ["iam:GetRole", "iam:GetOpenIDConnectProvider", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies"]
    resources = [
      aws_iam_role.app_deploy.arn,
      data.aws_iam_openid_connect_provider.github.arn,
    ]
  }

  statement {
    sid       = "Lambda"
    actions   = ["lambda:*"]
    resources = ["arn:aws:lambda:${var.region}:${local.account_id}:function:${local.iam_prefix}*"]
  }

  statement {
    sid     = "LambdaLogs"
    actions = ["logs:*"]
    resources = [
      "arn:aws:logs:${var.region}:${local.account_id}:log-group:/aws/lambda/${local.iam_prefix}*",
      "arn:aws:logs:${var.region}:${local.account_id}:log-group:/aws/lambda/${local.iam_prefix}*:*",
    ]
  }

  statement {
    sid       = "LogsDescribe"
    actions   = ["logs:DescribeLogGroups", "logs:ListTagsForResource"]
    resources = ["*"]
  }

  statement {
    sid       = "Ses"
    actions   = ["ses:*", "sesv2:*"]
    resources = ["*"]
  }

  statement {
    sid       = "Sns"
    actions   = ["sns:*"]
    resources = ["arn:aws:sns:${var.region}:${local.account_id}:${local.iam_prefix}*"]
  }

  statement {
    sid       = "CloudWatchAlarms"
    actions   = ["cloudwatch:*"]
    resources = ["*"]
  }

  statement {
    sid       = "Budgets"
    actions   = ["budgets:*"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadMisc"
    actions   = ["tag:GetResources", "sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "infra_apply" {
  name   = "terraform-main"
  role   = aws_iam_role.infra_apply.id
  policy = data.aws_iam_policy_document.infra_apply.json
}
