data "aws_caller_identity" "current" {}

locals {
  name = "vdd" # prefix for every IAM/Lambda/SNS name; the infra apply role is scoped to "vdd-*"

  contact_to   = coalesce(var.contact_to_address, "hello@${var.domain_name}")
  contact_from = "contact-form@${var.domain_name}"
  mail_from    = "mail.${var.domain_name}" # custom MAIL FROM (bounce) domain for SES
}
