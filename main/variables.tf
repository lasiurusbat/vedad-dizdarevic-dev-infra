variable "region" {
  description = "AWS region for the site bucket, Lambda and SES."
  type        = string
  default     = "eu-central-1"
}

variable "domain_name" {
  description = "Apex domain of the site."
  type        = string
  default     = "vedad-dizdarevic.dev"
}

variable "site_bucket_name" {
  description = "Globally unique name of the private site bucket. Must match bootstrap's var.site_bucket_name."
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID (owns the zone, Turnstile widget and Web Analytics site)."
  type        = string
}

variable "github_org" {
  description = "GitHub organisation (or user) that owns the app repo. Used to trust the key-rotation role."
  type        = string
}

variable "app_repo" {
  description = "Name of the app repo (without the org)."
  type        = string
}

variable "alert_email" {
  description = "Email that receives CloudWatch alarm (via SNS) and AWS Budgets notifications. Each subscription must be confirmed by clicking the link in the first mail."
  type        = string
}

variable "contact_to_address" {
  description = "Mailbox that receives contact-form submissions. Defaults to hello@<domain_name>."
  type        = string
  default     = null
}

variable "dmarc_policy" {
  description = "DMARC policy. Start at none, then quarantine, then reject once reports show only aligned mail."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "quarantine", "reject"], var.dmarc_policy)
    error_message = "dmarc_policy must be none, quarantine or reject."
  }
}

variable "dmarc_rua_email" {
  description = "Address for DMARC aggregate reports. Must be a mailbox you read, ideally on this domain."
  type        = string
}

variable "purelymail_ownership_proof" {
  description = "Value of the purelymail_ownership_proof=... TXT record shown in the Purelymail dashboard. Leave empty until you have it; the record is then skipped."
  type        = string
  default     = ""
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrency for the contact Lambda (cost and abuse cap). Brand-new AWS accounts have a total limit of 10 and AWS requires 10 unreserved, so a value >= 1 can fail until the limit is raised; set to -1 to leave unreserved."
  type        = number
  default     = -1 # AWS rejects any reservation on this account (total limit leaves < 10 unreserved)
}

variable "budget_limit_usd" {
  description = "Monthly AWS budget in USD (AWS Budgets only supports a fixed currency per budget)."
  type        = number
  default     = 5
}
