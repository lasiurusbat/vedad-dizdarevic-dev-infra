# Terraform owns the zone, its settings, DNS and rules. The Worker script and route are deployed
# with Wrangler from the app repo and must NOT be managed here.
resource "cloudflare_zone" "site" {
  account = {
    id = var.cloudflare_account_id
  }
  name = var.domain_name
  type = "full"
}

# After the first apply, switch the registrar's nameservers to these (see output `name_servers`).

locals {
  zone_settings = {
    ssl              = "strict" # Full (strict)
    always_use_https = "on"
    min_tls_version  = "1.2"
    tls_1_3          = "on"
    http3            = "on"
    brotli           = "on"
  }
}

resource "cloudflare_zone_setting" "this" {
  for_each = local.zone_settings

  zone_id    = cloudflare_zone.site.id
  setting_id = each.key
  value      = each.value
}

# Proxied placeholder records: the Worker route answers every request, so these only need to
# exist (and be proxied) for traffic to reach Cloudflare. 192.0.2.1 is a TEST-NET address.
resource "cloudflare_dns_record" "apex" {
  zone_id = cloudflare_zone.site.id
  name    = var.domain_name
  type    = "A"
  content = "192.0.2.1"
  proxied = true
  ttl     = 1 # automatic
  comment = "Placeholder; the Worker route handles requests"
}

resource "cloudflare_dns_record" "www" {
  zone_id = cloudflare_zone.site.id
  name    = "www.${var.domain_name}"
  type    = "A"
  content = "192.0.2.1"
  proxied = true
  ttl     = 1
  comment = "Placeholder; redirected to the apex by a Redirect Rule"
}

# www -> apex, 301, path and query preserved.
resource "cloudflare_ruleset" "redirects" {
  zone_id     = cloudflare_zone.site.id
  name        = "www to apex"
  description = "Managed by Terraform"
  kind        = "zone"
  phase       = "http_request_dynamic_redirect"

  rules = [
    {
      description = "Redirect www to apex"
      enabled     = true
      expression  = "(http.host eq \"www.${var.domain_name}\")"
      action      = "redirect"
      action_parameters = {
        from_value = {
          status_code           = 301
          preserve_query_string = true
          target_url = {
            expression = "concat(\"https://${var.domain_name}\", http.request.uri.path)"
          }
        }
      }
    }
  ]
}

# Rate limit for the contact endpoint. The free plan allows one rule with a 10 s period and a
# 10 s block, so this is a coarse burst limiter; Turnstile and the Lambda concurrency cap do
# the real work.
resource "cloudflare_ruleset" "rate_limit" {
  zone_id     = cloudflare_zone.site.id
  name        = "contact rate limit"
  description = "Managed by Terraform"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules = [
    {
      description = "Limit POST /api/contact per IP"
      enabled     = true
      expression  = "(http.request.uri.path eq \"/api/contact\" and http.request.method eq \"POST\")"
      action      = "block"
      ratelimit = {
        characteristics     = ["cf.colo.id", "ip.src"]
        period              = 10
        requests_per_period = 3
        mitigation_timeout  = 10
      }
    }
  ]
}

# Turnstile for the contact form. The site key is public (output). The secret key stays in
# Terraform state only; copy it from the Cloudflare dashboard into `wrangler secret put`.
resource "cloudflare_turnstile_widget" "contact" {
  account_id = var.cloudflare_account_id
  name       = "${var.domain_name} contact form"
  domains    = [var.domain_name]
  mode       = "managed"
  region     = "world"
}

# Cookieless analytics. The beacon is injected at the edge; the CSP already allows
# static.cloudflareinsights.com and cloudflareinsights.com.
resource "cloudflare_web_analytics_site" "site" {
  account_id   = var.cloudflare_account_id
  zone_tag     = cloudflare_zone.site.id
  auto_install = true
}
