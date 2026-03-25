# ── Cloud SQL Instance ────────────────────────────────────────────────────────
resource "google_sql_database_instance" "n8n" {
  name             = "n8n-postgres"
  database_version = var.db_version
  region           = var.region
  deletion_protection = false

  settings {
    tier = "db-f1-micro"

    # Private IP only — no public exposure
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.vpc.self_link
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled    = true
      start_time = "02:00"
    }
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# ── Database ──────────────────────────────────────────────────────────────────
resource "google_sql_database" "n8n" {
  name     = "n8n"
  instance = google_sql_database_instance.n8n.name
}

# ── Database User ─────────────────────────────────────────────────────────────
resource "google_sql_user" "n8n" {
  name     = "n8n"
  instance = google_sql_database_instance.n8n.name
  password = var.db_password
}
