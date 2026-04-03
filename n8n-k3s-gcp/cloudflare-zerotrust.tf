# ── Zero Trust Device Profile ─────────────────────────────────────────────────
# Default profile — applies to all enrolled devices.
# service_mode_v2_mode "tunnel" routes traffic through WARP tunnel.
resource "cloudflare_zero_trust_device_profiles" "default" {
  account_id        = var.cloudflare_account_id
  name              = "Default"
  description       = "Default device profile for all enrolled devices"
  default           = true
  enabled           = true
  service_mode_v2_mode = "warp"
  service_mode_v2_port = 0
}

# ── Split Tunnel — Include Mode ───────────────────────────────────────────────
# Only traffic destined for GKE CIDRs goes through WARP.
# Everything else (normal internet) goes direct — no performance impact.
resource "cloudflare_zero_trust_split_tunnel" "include" {
  account_id = var.cloudflare_account_id
  policy_id  = cloudflare_zero_trust_device_profiles.default.id
  mode       = "include"

  tunnels {
    address     = "10.10.0.0/24"
    description = "GKE node subnet"
  }
  tunnels {
    address     = "10.64.0.0/14"
    description = "GKE pod CIDR"
  }
  tunnels {
    address     = "34.118.224.0/20"
    description = "GKE service CIDR"
  }
  tunnels {
    address     = "34.13.11.8/32"
    description = "GKE master public endpoint (zone)"
  }
  tunnels {
    address     = "34.13.57.117/32"
    description = "GKE master public endpoint (region)"
  }
}

# ── Gateway DNS Policies — private service overrides ─────────────────────────
# When WARP is active, each hostname resolves to Traefik's ClusterIP.
# Traffic routes through the tunnel to the GKE service CIDR.
# No public DNS records exist for any of these — WARP is the only path in.

resource "cloudflare_zero_trust_gateway_policy" "grafana_dns_override" {
  account_id  = var.cloudflare_account_id
  name        = "grafana-private-dns"
  description = "Resolve grafana.gbone.one to Traefik ClusterIP for WARP clients"
  precedence  = 1
  enabled     = true
  action      = "override"
  filters     = ["dns"]
  traffic     = "dns.fqdn == \"grafana.gbone.one\""

  rule_settings {
    override_ips = ["34.118.228.195"]
  }
}

resource "cloudflare_zero_trust_gateway_policy" "n8n_dns_override" {
  account_id  = var.cloudflare_account_id
  name        = "n8n-private-dns"
  description = "Resolve n8n.gbone.one to Traefik ClusterIP for WARP clients"
  precedence  = 2
  enabled     = true
  action      = "override"
  filters     = ["dns"]
  traffic     = "dns.fqdn == \"n8n.gbone.one\""

  rule_settings {
    override_ips = ["34.118.228.195"]
  }
}

resource "cloudflare_zero_trust_gateway_policy" "affine_dns_override" {
  account_id  = var.cloudflare_account_id
  name        = "affine-private-dns"
  description = "Resolve affine.gbone.one to Traefik ClusterIP for WARP clients"
  precedence  = 3
  enabled     = true
  action      = "override"
  filters     = ["dns"]
  traffic     = "dns.fqdn == \"affine.gbone.one\""

  rule_settings {
    override_ips = ["34.118.228.195"]
  }
}

resource "cloudflare_zero_trust_gateway_policy" "prometheus_dns_override" {
  account_id  = var.cloudflare_account_id
  name        = "prometheus-private-dns"
  description = "Resolve prometheus.gbone.one to Traefik ClusterIP for WARP clients"
  precedence  = 4
  enabled     = true
  action      = "override"
  filters     = ["dns"]
  traffic     = "dns.fqdn == \"prometheus.gbone.one\""

  rule_settings {
    override_ips = ["34.118.228.195"]
  }
}

resource "cloudflare_zero_trust_gateway_policy" "traefik_dns_override" {
  account_id  = var.cloudflare_account_id
  name        = "traefik-private-dns"
  description = "Resolve traefik.gbone.one to Traefik ClusterIP for WARP clients"
  precedence  = 5
  enabled     = true
  action      = "override"
  filters     = ["dns"]
  traffic     = "dns.fqdn == \"traefik.gbone.one\""

  rule_settings {
    override_ips = ["34.118.228.195"]
  }
}

# ── Device Enrollment Permissions ─────────────────────────────────────────────
# Only this email can enroll devices into the Zero Trust organisation.
resource "cloudflare_zero_trust_access_organization" "main" {
  account_id      = var.cloudflare_account_id
  name            = "gbone23.cloudflareaccess.com"
  auth_domain     = "gbone23.cloudflareaccess.com"
  is_ui_read_only = false
}

# ── WARP Enrollment App + Policy ───────────────────────────────────────────────
# Built-in "warp" Access application — controls who can enroll devices.
# Auto-created by Cloudflare when Zero Trust plan was activated; imported here.
resource "cloudflare_zero_trust_access_application" "warp_enrollment" {
  account_id           = var.cloudflare_account_id
  name                 = "Warp Login App"
  type                 = "warp"
  session_duration     = "24h"
  app_launcher_visible = false
}

resource "cloudflare_zero_trust_access_policy" "warp_enrollment" {
  account_id = var.cloudflare_account_id
  name       = "Allow graylaye@googlemail.com"
  decision   = "allow"

  include {
    email = ["graylaye@googlemail.com"]
  }
}
