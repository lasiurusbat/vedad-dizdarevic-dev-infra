# AWS managed key alias/aws/sns cannot be used by CloudWatch alarms and Budgets to publish, and a customer managed key costs money; the topic carries alarm text only
#trivy:ignore:AWS-0095
resource "aws_sns_topic" "alerts" {
  #checkov:skip=CKV_AWS_26:AWS managed key alias/aws/sns cannot be used by CloudWatch alarms and Budgets to publish, and a customer managed key costs money; the topic carries alarm text only
  name = "${local.name}-alerts"
}

# Email subscriptions stay "pending" until the recipient clicks the confirmation link.
resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name}-contact-lambda-errors"
  alarm_description   = "Contact Lambda returned errors."
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.contact.function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${local.name}-contact-lambda-throttles"
  alarm_description   = "Contact Lambda was throttled (account-wide concurrency limit reached)."
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  dimensions          = { FunctionName = aws_lambda_function.contact.function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

# Concurrency is not reserved on this account (AWS rejects it), so the throttle alarm above only fires at the
# account-wide limit. Turnstile and the Worker's checks are the brakes; this alarm tells us when they are
# being leaned on. A handful of real messages a day is normal, so 30 in an hour is not a visitor.
resource "aws_cloudwatch_metric_alarm" "lambda_invocations" {
  alarm_name          = "${local.name}-contact-lambda-invocations"
  alarm_description   = "Contact Lambda invoked more than 30 times in an hour (abuse, or a loop). [rollback test]"
  namespace           = "AWS/Lambda"
  metric_name         = "Invocations"
  dimensions          = { FunctionName = aws_lambda_function.contact.function_name }
  statistic           = "Sum"
  period              = 3600
  evaluation_periods  = 1
  threshold           = 30
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

# AWS pauses sending at 10% bounce / 0.5% complaint rate (review at 5% / 0.1%), so alarm below that.
resource "aws_cloudwatch_metric_alarm" "ses_bounce_rate" {
  alarm_name          = "${local.name}-ses-bounce-rate"
  alarm_description   = "SES account bounce rate above 5%."
  namespace           = "AWS/SES"
  metric_name         = "Reputation.BounceRate"
  statistic           = "Maximum"
  period              = 3600
  evaluation_periods  = 1
  threshold           = 0.05
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "ses_complaint_rate" {
  alarm_name          = "${local.name}-ses-complaint-rate"
  alarm_description   = "SES account complaint rate above 0.1%."
  namespace           = "AWS/SES"
  metric_name         = "Reputation.ComplaintRate"
  statistic           = "Maximum"
  period              = 3600
  evaluation_periods  = 1
  threshold           = 0.001
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_budgets_budget" "monthly" {
  name         = "${local.name}-monthly"
  budget_type  = "COST"
  time_unit    = "MONTHLY"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"

  # The account is shared with sorted.onl; without this filter the budget
  # tracks (and forecasts) the whole account. Needs the Project tag to be
  # active as a cost allocation tag (Billing console, not managed here).
  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Project$vedad-dizdarevic.dev"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
