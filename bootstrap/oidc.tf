# One GitHub OIDC provider per AWS account; it already exists, so reference it.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_host = "token.actions.githubusercontent.com"
  infra_sub = "repo:${var.github_org}/${var.infra_repo}"
  app_sub   = "repo:${var.github_org}/${var.app_repo}"
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
