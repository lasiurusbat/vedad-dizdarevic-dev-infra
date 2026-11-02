data "archive_file" "contact_placeholder" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_placeholder"
  output_path = "${path.module}/.build/contact-placeholder.zip"
}

resource "aws_cloudwatch_log_group" "contact" {
  name              = "/aws/lambda/${local.name}-contact"
  retention_in_days = 30
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "contact" {
  name               = "${local.name}-contact-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

data "aws_iam_policy_document" "contact" {
  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.contact.arn}:*"]
  }

  # Limited to the verified domain identity and the configuration set (needed because mail is
  # sent through it so reputation metrics exist).
  statement {
    sid       = "SendContactMail"
    actions   = ["ses:SendEmail"]
    resources = [aws_sesv2_email_identity.domain.arn, aws_sesv2_configuration_set.contact.arn]
  }
}

resource "aws_iam_role_policy" "contact" {
  name   = "logs-and-ses-send"
  role   = aws_iam_role.contact.id
  policy = data.aws_iam_policy_document.contact.json
}

resource "aws_lambda_function" "contact" {
  function_name = "${local.name}-contact"
  role          = aws_iam_role.contact.arn
  runtime       = "nodejs24.x"
  architectures = ["arm64"]
  handler       = "index.handler"
  memory_size   = 128
  timeout       = 10

  reserved_concurrent_executions = var.lambda_reserved_concurrency

  filename         = data.archive_file.contact_placeholder.output_path
  source_code_hash = data.archive_file.contact_placeholder.output_base64sha256

  environment {
    variables = {
      CONTACT_TO_ADDRESS    = local.contact_to
      CONTACT_FROM_ADDRESS  = local.contact_from
      SES_CONFIGURATION_SET = aws_sesv2_configuration_set.contact.configuration_set_name
    }
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.contact.name
  }

  # The real code is shipped from the app repo. Terraform owns the configuration only.
  lifecycle {
    ignore_changes = [filename, source_code_hash, s3_bucket, s3_key, s3_object_version]
  }

  depends_on = [aws_iam_role_policy.contact]
}

# AWS_IAM auth: unsigned requests get 403. Only the Worker user (worker_iam.tf) may call it.
resource "aws_lambda_function_url" "contact" {
  function_name      = aws_lambda_function.contact.function_name
  authorization_type = "AWS_IAM"
}
