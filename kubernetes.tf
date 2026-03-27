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
