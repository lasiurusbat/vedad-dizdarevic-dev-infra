# ---- Mailbox provider (Purelymail) -----------------------------------------------------------
# Record values follow Purelymail's setup guide; compare with the DNS page in its dashboard
# before applying, as providers occasionally change them.

resource "cloudflare_dns_record" "mx" {
  zone_id  = cloudflare_zone.site.id
  name     = var.domain_name
  type     = "MX"
  content  = "mailserver.purelymail.com"
  priority = 50 # per Purelymail setup docs
  ttl      = 3600
}

# One SPF record per name. The apex sends only via the mailbox provider; SES sends with the
# custom MAIL FROM subdomain (below), which carries its own SPF record, and DMARC aligns on it.
resource "cloudflare_dns_record" "spf" {
  zone_id = cloudflare_zone.site.id
  name    = var.domain_name
  type    = "TXT"
  content = "\"v=spf1 include:_spf.purelymail.com ~all\""
  ttl     = 3600
}

resource "cloudflare_dns_record" "purelymail_ownership" {
  count = var.purelymail_ownership_proof == "" ? 0 : 1

  zone_id = cloudflare_zone.site.id
  name    = var.domain_name
  type    = "TXT"
  content = "\"purelymail_ownership_proof=${var.purelymail_ownership_proof}\""
  ttl     = 3600
}

resource "cloudflare_dns_record" "purelymail_dkim" {
  for_each = toset(["1", "2", "3"])

  zone_id = cloudflare_zone.site.id
  name    = "purelymail${each.key}._domainkey.${var.domain_name}"
  type    = "CNAME"
  content = "key${each.key}.dkimroot.purelymail.com"
  proxied = false
  ttl     = 3600
}

# ---- SES (contact form) ----------------------------------------------------------------------
# DKIM: three CNAMEs from the SES identity (Easy DKIM).
resource "cloudflare_dns_record" "ses_dkim" {
  count = 3

  zone_id = cloudflare_zone.site.id
  name    = "${aws_sesv2_email_identity.domain.dkim_signing_attributes[0].tokens[count.index]}._domainkey.${var.domain_name}"
  type    = "CNAME"
  content = "${aws_sesv2_email_identity.domain.dkim_signing_attributes[0].tokens[count.index]}.dkim.amazonses.com"
  proxied = false
  ttl     = 3600
}

# Custom MAIL FROM domain: MX for bounces + SPF.
resource "cloudflare_dns_record" "ses_mail_from_mx" {
  zone_id  = cloudflare_zone.site.id
  name     = local.mail_from
  type     = "MX"
  content  = "feedback-smtp.${var.region}.amazonses.com"
  priority = 10
  ttl      = 3600
}

resource "cloudflare_dns_record" "ses_mail_from_spf" {
  zone_id = cloudflare_zone.site.id
  name    = local.mail_from
  type    = "TXT"
  content = "\"v=spf1 include:amazonses.com ~all\""
  ttl     = 3600
}

# ---- DMARC -----------------------------------------------------------------------------------
resource "cloudflare_dns_record" "dmarc" {
  zone_id = cloudflare_zone.site.id
  name    = "_dmarc.${var.domain_name}"
  type    = "TXT"
  content = "\"v=DMARC1; p=${var.dmarc_policy}; rua=mailto:${var.dmarc_rua_email}; adkim=r; aspf=r\""
  ttl     = 3600
}
