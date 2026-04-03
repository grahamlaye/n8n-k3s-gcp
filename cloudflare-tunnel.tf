# ── Tunnel Secret ─────────────────────────────────────────────────────────────
# 32-byte random secret cloudflared uses to authenticate to Cloudflare.
# Generated once, stored in GCS state (encrypted at rest). Never manually managed.
resource "random_id" "tunnel_secret" {
  byte_length = 32
}

# ── Cloudflare Tunnel ─────────────────────────────────────────────────────────
resource "cloudflare_zero_trust_tunnel_cloudflared" "gke" {
  account_id = var.cloudflare_account_id
  name       = "gke-n8n"
  secret     = random_id.tunnel_secret.b64_std
}

# ── Tunnel Ingress Config ─────────────────────────────────────────────────────
# Wildcard rule: any *.gbone.one hostname routed through the tunnel hits Traefik.
# warp_routing enabled so WARP-enrolled devices can reach private network CIDRs.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "gke" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.gke.id

  config {
    warp_routing {
      enabled = true
    }

    ingress_rule {
      hostname = "*.gbone.one"
      service  = "https://traefik.traefik.svc.cluster.local:443"
      origin_request {
        no_tls_verify = true
      }
    }
    # Catch-all required by Cloudflare schema — unreachable in practice since the
    # wildcard above matches everything. Traefik's gnome 404 handles unknown hostnames.
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# ── Private Network Routes ────────────────────────────────────────────────────
# These three CIDRs cover all reachable addresses inside the GKE cluster.
# WARP-enrolled devices will route traffic to these ranges through the tunnel.

resource "cloudflare_zero_trust_tunnel_route" "nodes" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.gke.id
  network    = "10.10.0.0/24"
  comment    = "GKE node subnet"
}

resource "cloudflare_zero_trust_tunnel_route" "pods" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.gke.id
  network    = "10.64.0.0/14"
  comment    = "GKE pod CIDR"
}

resource "cloudflare_zero_trust_tunnel_route" "services" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.gke.id
  network    = "34.118.224.0/20"
  comment    = "GKE service CIDR (Traefik ClusterIP: 34.118.228.195)"
}

resource "cloudflare_zero_trust_tunnel_route" "gke_master_zone" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.gke.id
  network    = "34.13.11.8/32"
  comment    = "GKE master public endpoint (zone)"
}

resource "cloudflare_zero_trust_tunnel_route" "gke_master_region" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.gke.id
  network    = "34.13.57.117/32"
  comment    = "GKE master public endpoint (region)"
}

# ── DNS Zone ──────────────────────────────────────────────────────────────────
data "cloudflare_zone" "gbone_one" {
  name = "gbone.one"
}

# ── DNS Records ───────────────────────────────────────────────────────────────
# Explicit records for every service — no wildcard.
# Services on the public path use proxied A records pointing at the GCP public ingress IP.
# Services migrated to the private tunnel have no public DNS record — WARP only.
#
# k8s.gbone.one intentionally omitted — kubectl access will be added in phase 2
# with a proper Cloudflare Access policy. No public access to preserve in the meantime.

locals {
  # GCP static external IP — attached to the Traefik LoadBalancer service in GKE.
  # If a second public ingress IP is ever provisioned, add gcp_public_ingress_ip_002 etc.
  gcp_public_ingress_ip_001 = "34.105.214.176"
}

# All services are private — no public DNS records.
# Access via WARP: Gateway DNS overrides resolve each hostname to Traefik ClusterIP
# (34.118.228.195), routed through the tunnel to the GKE service CIDR.
