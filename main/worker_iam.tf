# The one long-lived key in the setup. Terraform creates the USER ONLY. Create the access key by
# hand (or with the rotation workflow) and store it with `wrangler secret put`, so the secret
# never lands in Terraform state or outputs.
resource "aws_iam_user" "worker" {
  #checkov:skip=CKV_AWS_273:Cloudflare Workers cannot assume an IAM role or use SSO; this one scoped long-lived key is the documented exception, rotated every 90 days
  name = "${local.name}-worker"
  path = "/service/"

  lifecycle {
    # The IAM console stores an access key's description as a tag on the user (key id to
    # description), so tags change outside Terraform every time the key is rotated.
    ignore_changes = [tags, tags_all]
  }
}

data "aws_iam_policy_document" "worker" {
  statement {
    sid       = "ReadSiteObjects"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]
  }

  # AWS_IAM function URLs need BOTH actions. InvokeFunction is pinned to calls made through the
  # function URL, so this user cannot call the function through the Lambda API.
  statement {
    sid       = "InvokeContactFunctionUrl"
    actions   = ["lambda:InvokeFunctionUrl"]
    resources = [aws_lambda_function.contact.arn]

    condition {
      test     = "StringEquals"
      variable = "lambda:FunctionUrlAuthType"
      values   = ["AWS_IAM"]
    }
  }

  statement {
    sid       = "InvokeContactFunctionViaUrlOnly"
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.contact.arn]

    condition {
      test     = "Bool"
      variable = "lambda:InvokedViaFunctionUrl"
      values   = ["true"]
    }
  }
}

resource "aws_iam_user_policy" "worker" {
  #checkov:skip=CKV_AWS_40:The policy is attached to a single-purpose user that exists only for the Worker; a group would add indirection
  name   = "site-read-and-contact-invoke"
  user   = aws_iam_user.worker.name
  policy = data.aws_iam_policy_document.worker.json
}

# ---------------------------------------------------------------------------------------------
# Key-rotation role (Phase 10): assumed by the app repo's scheduled workflow on main. It can only
# manage access keys of the Worker user.
# ---------------------------------------------------------------------------------------------
# Looked up by ARN, not URL: a URL lookup calls iam:ListOpenIDConnectProviders, which the CI apply
# role does not (and should not need to) have.
data "aws_iam_openid_connect_provider" "github" {
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "rotation_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      # The immutable subject, like the bootstrap roles: a subject built from names does not match.
      values = ["repo:${var.github_org}@${var.github_owner_id}/${var.app_repo}@${var.app_repo_id}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "key_rotation" {
  name                 = "${local.name}-key-rotation"
  assume_role_policy   = data.aws_iam_policy_document.rotation_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "key_rotation" {
  statement {
    actions   = ["iam:ListAccessKeys", "iam:CreateAccessKey", "iam:DeleteAccessKey", "iam:UpdateAccessKey"]
    resources = [aws_iam_user.worker.arn]
  }
}

resource "aws_iam_role_policy" "key_rotation" {
  name   = "rotate-worker-key"
  role   = aws_iam_role.key_rotation.id
  policy = data.aws_iam_policy_document.key_rotation.json
}
