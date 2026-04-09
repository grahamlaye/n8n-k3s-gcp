# ── In-cluster PostgreSQL (pgvector) ──────────────────────────────────────────
# Single-replica StatefulSet running pgvector/pgvector:pg16.
# Migration target from Cloud SQL. Apps continue pointing at Cloud SQL
# until a future cutover phase — no connection strings are changed here.

resource "random_password" "incluster_postgres" {
  length  = 32
  special = false # avoid shell escaping issues during pg_dump/pg_restore
}

resource "google_secret_manager_secret" "incluster_postgres_password" {
  secret_id = "incluster-postgres-password"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "incluster_postgres_password" {
  secret      = google_secret_manager_secret.incluster_postgres_password.id
  secret_data = random_password.incluster_postgres.result
}

# ── Namespace ─────────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "postgres" {
  metadata {
    name = "postgres"
  }

  depends_on = [google_container_cluster.primary]
}

# ── Credentials secret ────────────────────────────────────────────────────────

resource "kubernetes_secret" "incluster_postgres" {
  metadata {
    name      = "postgres-credentials"
    namespace = kubernetes_namespace.postgres.metadata[0].name
  }

  data = {
    POSTGRES_USER     = "postgres"
    POSTGRES_PASSWORD = google_secret_manager_secret_version.incluster_postgres_password.secret_data
    POSTGRES_DB       = "postgres"
  }
}

# ── PVC — 1 Gi ────────────────────────────────────────────────────────────────

resource "kubernetes_persistent_volume_claim" "postgres" {
  metadata {
    name      = "postgres-data"
    namespace = kubernetes_namespace.postgres.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "standard-rwo"

    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }

  wait_until_bound = false
}

# ── StatefulSet ───────────────────────────────────────────────────────────────

resource "kubernetes_stateful_set" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.postgres.metadata[0].name
    labels = {
      app = "postgres"
    }
  }

  spec {
    service_name = "postgres"
    replicas     = 1

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "pgvector/pgvector:pg16"

          # PGDATA must be a subdirectory — Postgres refuses to start if the
          # mount root is non-empty (k8s adds a lost+found dir on ext4 volumes).
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.incluster_postgres.metadata[0].name
            }
          }

          port {
            name           = "postgres"
            container_port = 5432
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "256Mi"
            }
            limits = {
              memory = "512Mi"
            }
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres"]
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            failure_threshold     = 3
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres"]
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            failure_threshold     = 5
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.postgres,
    kubernetes_persistent_volume_claim.postgres,
  ]
}

# ── ClusterIP Service ─────────────────────────────────────────────────────────
# Reachable cluster-wide as postgres.postgres.svc.cluster.local:5432

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.postgres.metadata[0].name
    labels = {
      app = "postgres"
    }
  }

  spec {
    selector = {
      app = "postgres"
    }

    port {
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_namespace.postgres]
}
