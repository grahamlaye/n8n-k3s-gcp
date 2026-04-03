# Cloudflare Zero Trust — Setup Reference

This document explains what's configured, why, and how to navigate the Cloudflare dashboard if you need to make manual changes or diagnose issues.

## Architecture Overview

All services are **private-only**. No public DNS records exist for any `*.gbone.one` service.

```
Your device (WARP on)
  └── Cloudflare Gateway DNS → resolves *.gbone.one to Traefik ClusterIP (34.118.228.195)
  └── WARP tunnel → routes GKE CIDRs through cloudflared pods in GKE
        └── Traefik (34.118.228.195) → routes to correct pod
```

With WARP off: all `*.gbone.one` domains return NXDOMAIN — completely unreachable.

## Services and Their Private IPs

All resolve to Traefik ClusterIP `34.118.228.195` — Traefik handles internal routing.

| Domain | Routed to |
|---|---|
| grafana.gbone.one | prometheus-stack-grafana (monitoring ns) |
| n8n.gbone.one | n8n (n8n ns) |
| affine.gbone.one | affine (affine ns) |
| prometheus.gbone.one | prometheus (monitoring ns) |
| traefik.gbone.one | Traefik dashboard (traefik ns) |

## Cloudflare Dashboard Navigation

The Cloudflare Zero Trust console is at: **one.dash.cloudflare.com**

### Gateway DNS Overrides
**Where:** Zero Trust → Gateway → Firewall Policies → DNS

These are the rules that intercept DNS queries for `*.gbone.one` and return the Traefik ClusterIP instead. One rule per service. If a service stops resolving via WARP, check here first.

### Split Tunnel (WARP routing)
**Where:** Zero Trust → Settings → WARP Client → Device settings → (Default profile) → Split Tunnels

Set to **Include** mode — only these CIDRs route through WARP:
- `10.10.0.0/24` — GKE node subnet
- `10.64.0.0/14` — GKE pod CIDR
- `34.118.224.0/20` — GKE service CIDR (includes Traefik at 34.118.228.195)

Everything else (normal internet) goes direct.

### Device Enrollment
**Where:** Zero Trust → Settings → WARP Client → Device enrollment permissions

Only `graylaye@googlemail.com` can enroll devices. Uses One-time PIN (OTP) for authentication — no external IdP needed.

### WARP Enrollment App
**Where:** Zero Trust → Access → Applications → "Warp Login App"

The built-in Access application controlling device enrollment. Has one policy allowing `graylaye@googlemail.com`.

## TLS Certificates

A single wildcard `*.gbone.one` Let's Encrypt cert is managed by cert-manager in the GKE cluster.

- **Certificate resource:** `wildcard-gbone-one` in `traefik` namespace
- **Secret:** `wildcard-gbone-one-tls` in `traefik` namespace
- **Traefik TLSStore:** `default` in `traefik` namespace — serves this cert for all HTTPS routes
- **Renewal:** Automatic via cert-manager DNS-01 challenge against Cloudflare API
- **Renewal dependency:** Cloudflare god-token must allow GKE NAT egress IP (`35.214.53.241`)
- **Next renewal:** ~2026-06-27 (90 days from issuance)

⚠️ **Action needed before renewal:** Replace god-token usage with a scoped DNS-only token (see project memory).

## Cloudflare Account Details

- **Account:** gbone23
- **Team domain:** gbone23.cloudflareaccess.com
- **Zone:** gbone.one (ID: 89c6d0a290c76b963e820a6944dbd68a)
- **API token:** stored in GCP Secret Manager as `cloudflare-api-token`

## Everything is Terraform-managed

All of the above is in `cloudflare-tunnel.tf` and `cloudflare-zerotrust.tf`. 
Do not make structural changes via the dashboard — use Terraform and run `terraform apply`.

## Troubleshooting

**Service not loading with WARP on:**
1. Check WARP is connected (system tray icon)
2. `nslookup grafana.gbone.one` — should return `34.118.228.195`, not NXDOMAIN
3. If NXDOMAIN: check Gateway DNS policy exists in dashboard
4. If wrong IP: Gateway DNS override may be missing or wrong IP
5. If connection refused: check cloudflared pods are running — `kubectl get pods -n cloudflared`

**cert-manager renewal fails:**
1. Check Cloudflare god-token still allows `35.214.53.241`
2. `kubectl describe certificate wildcard-gbone-one -n traefik`
3. `kubectl get challenges -A`
