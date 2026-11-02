# One GitHub OIDC provider per AWS account; it already exists, so reference it.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_host = "token.actions.githubusercontent.com"
  # These repos use GitHub immutable OIDC subjects: repo:<owner>@<ownerId>/<repo>@<repoId>.
  # Pinning the numeric IDs means a deleted-and-recreated repo (or a re-registered name) cannot assume these roles.
  infra_sub = "repo:${var.github_org}@${var.github_owner_id}/${var.infra_repo}@${var.infra_repo_id}"
  app_sub   = "repo:${var.github_org}@${var.github_owner_id}/${var.app_repo}@${var.app_repo_id}"
}

# Trust policies: each role is limited to one repo and one ref (or environment / PR event).
data "aws_iam_policy_document" "trust_infra_apply" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values = [
        "${local.infra_sub}:ref:refs/heads/main",
        "${local.infra_sub}:environment:${var.infra_apply_environment}",
      ]
    }
  }
}

data "aws_iam_policy_document" "trust_infra_plan" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["${local.infra_sub}:pull_request"]
    }
  }
}

data "aws_iam_policy_document" "trust_app_deploy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["${local.app_sub}:ref:refs/heads/main"]
    }
  }
}
