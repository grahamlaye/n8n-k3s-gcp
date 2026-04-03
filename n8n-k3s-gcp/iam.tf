# ── GCP Service Account for Cloud SQL proxy ───────────────────────────────────
# Shared by n8n and Affine pods via Workload Identity.
# The proxy sidecar uses this SA to authenticate to Cloud SQL —
# no IP dependency, survives instance recreation.

resource "google_service_account" "cloudsql_proxy" {
  account_id   = "cloudsql-proxy"
  display_name = "Cloud SQL Proxy (n8n + Affine)"
  project      = var.project_id
}

resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloudsql_proxy.email}"
}

# ── Workload Identity bindings ────────────────────────────────────────────────
# Binds the GCP SA to the K8s SAs in each namespace so the proxy sidecar
# can authenticate without any key files.

resource "google_service_account_iam_member" "n8n_workload_identity" {
  service_account_id = google_service_account.cloudsql_proxy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[n8n/cloudsql-proxy]"
}

resource "google_service_account_iam_member" "affine_workload_identity" {
  service_account_id = google_service_account.cloudsql_proxy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[affine/cloudsql-proxy]"
}

# ── K8s Service Accounts (annotated for Workload Identity) ───────────────────

resource "kubernetes_service_account" "n8n_cloudsql_proxy" {
  metadata {
    name      = "cloudsql-proxy"
    namespace = "n8n"
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.cloudsql_proxy.email
    }
  }

  depends_on = [google_container_cluster.primary]
}

resource "kubernetes_service_account" "affine_cloudsql_proxy" {
  metadata {
    name      = "cloudsql-proxy"
    namespace = "affine"
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.cloudsql_proxy.email
    }
  }

  depends_on = [kubernetes_namespace.affine]
}
