# ── Kubernetes Provider ───────────────────────────────────────────────────────
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# ── n8n ConfigMap — populated from Terraform outputs ─────────────────────────
resource "kubernetes_config_map" "n8n_config" {
  metadata {
    name      = "n8n-config"
    namespace = "n8n"
  }

  data = {
    DB_POSTGRESDB_HOST = google_sql_database_instance.n8n.private_ip_address
    DB_POSTGRESDB_PORT = "5432"
    DB_POSTGRESDB_DATABASE = "n8n"
  }

  depends_on = [google_container_cluster.primary]
}
