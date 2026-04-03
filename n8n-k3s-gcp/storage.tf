# ── GCP APIs ─────────────────────────────────────────────────────────────────
resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# ── GCS Remote State Bucket ───────────────────────────────────────────────────
resource "google_storage_bucket" "tfstate" {
  name                        = "n8n-demo-lab-tfstate"
  location                    = "EU"
  force_destroy               = false
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}
