# ── Kubernetes Provider ───────────────────────────────────────────────────────
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# ── n8n ConfigMap ─────────────────────────────────────────────────────────────
# DB_POSTGRESDB_HOST points to localhost — the Cloud SQL Auth Proxy sidecar
# handles the actual connection, so this never breaks when the Cloud SQL IP changes.
resource "kubernetes_config_map" "n8n_config" {
  metadata {
    name      = "n8n-config"
    namespace = "n8n"
  }

  data = {
    DB_POSTGRESDB_HOST     = "127.0.0.1"
    DB_POSTGRESDB_PORT     = "5432"
    DB_POSTGRESDB_DATABASE = "n8n"
  }

  depends_on = [google_container_cluster.primary]
}

# ── Cloudflared ───────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "cloudflared" {
  metadata {
    name = "cloudflared"
  }

  depends_on = [google_container_cluster.primary]
}

resource "kubernetes_secret" "tunnel_credentials" {
  metadata {
    name      = "tunnel-credentials"
    namespace = kubernetes_namespace.cloudflared.metadata[0].name
  }

  data = {
    token = cloudflare_zero_trust_tunnel_cloudflared.gke.tunnel_token
  }
}

resource "kubernetes_deployment" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace.cloudflared.metadata[0].name
    labels = {
      app = "cloudflared"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "cloudflared"
      }
    }

    template {
      metadata {
        labels = {
          app = "cloudflared"
        }
      }

      spec {
        affinity {
          pod_anti_affinity {
            # Soft: prefer different nodes, but don't block scheduling if only one node exists
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_labels = {
                    app = "cloudflared"
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        container {
          name  = "cloudflared"
          image = "cloudflare/cloudflared:2026.3.0"
          args  = ["tunnel", "--no-autoupdate", "--metrics", "0.0.0.0:2000", "run"]

          env {
            name = "TUNNEL_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.tunnel_credentials.metadata[0].name
                key  = "token"
              }
            }
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "64Mi"
            }
            limits = {
              memory = "128Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/ready"
              port = 2000
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            failure_threshold     = 3
          }
        }
      }
    }
  }

  # Ensure tunnel config is pushed to Cloudflare before pods start
  depends_on = [cloudflare_zero_trust_tunnel_cloudflared_config.gke]
}

# ── cert-manager Cloudflare API token ────────────────────────────────────────
# cert-manager reads this secret when performing DNS-01 challenges via Cloudflare.
# Token sourced from GCP Secret Manager — same pattern as all other secrets.
resource "kubernetes_secret" "cloudflare_api_token_cert_manager" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = "cert-manager"
  }

  data = {
    api-token = data.google_secret_manager_secret_version.cloudflare_api_token.secret_data
  }
}

# ── Affine Namespace ──────────────────────────────────────────────────────────
resource "kubernetes_namespace" "affine" {
  metadata {
    name = "affine"
  }

  depends_on = [google_container_cluster.primary]
}

# ── Affine ConfigMap ──────────────────────────────────────────────────────────
resource "kubernetes_config_map" "affine_config" {
  metadata {
    name      = "affine-config"
    namespace = "affine"
  }

  data = {
    DB_HOST                  = "127.0.0.1"
    DB_PORT                  = "5432"
    DB_NAME                  = "affine"
    DB_USER                  = "affine"
    REDIS_SERVER_HOST        = "redis.affine.svc.cluster.local"
    REDIS_SERVER_PORT        = "6379"
    AFFINE_SERVER_PORT       = "3010"
    AFFINE_SERVER_EXTERNAL_URL = "https://affine.gbone.one"
    NODE_ENV                 = "production"
  }

  depends_on = [kubernetes_namespace.affine]
}
