# ── Secret Manager — data sources ────────────────────────────────────────────
# Terraform reads from Secret Manager at apply time.
# K8s secrets are created/reconciled from these values.
# Pods never call Secret Manager at runtime — they use K8s secrets as env vars.

data "google_secret_manager_secret_version" "n8n_db_password" {
  secret  = "n8n-db-password"
  project = var.project_id
}

data "google_secret_manager_secret_version" "rag_db_password" {
  secret  = "rag-db-password"
  project = var.project_id
}

data "google_secret_manager_secret_version" "affine_db_password" {
  secret  = "affine-db-password"
  project = var.project_id
}

data "google_secret_manager_secret_version" "n8n_encryption_key" {
  secret  = "n8n-encryption-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "n8n_runners_auth_token" {
  secret  = "n8n-runners-auth-token"
  project = var.project_id
}

data "google_secret_manager_secret_version" "affine_nextauth_secret" {
  secret  = "affine-nextauth-secret"
  project = var.project_id
}

data "google_secret_manager_secret_version" "affine_admin_email" {
  secret  = "affine-admin-email"
  project = var.project_id
}

data "google_secret_manager_secret_version" "affine_admin_password" {
  secret  = "affine-admin-password"
  project = var.project_id
}

data "google_secret_manager_secret_version" "cloudflare_api_token" {
  secret  = "cloudflare-api-token"
  project = var.project_id
}

data "google_secret_manager_secret_version" "gemini_api_key" {
  secret  = "gemini-api-key"
  project = var.project_id
}

# ── K8s Secrets — owned by Terraform ─────────────────────────────────────────
# If a secret is accidentally deleted from the cluster, tf apply restores it.

resource "kubernetes_secret" "postgres_secret" {
  metadata {
    name      = "postgres-secret"
    namespace = "n8n"
  }

  data = {
    POSTGRES_USER              = "n8n"
    POSTGRES_PASSWORD          = data.google_secret_manager_secret_version.n8n_db_password.secret_data
    POSTGRES_DB                = "n8n"
    POSTGRES_NON_ROOT_USER     = "n8n"
    POSTGRES_NON_ROOT_PASSWORD = data.google_secret_manager_secret_version.n8n_db_password.secret_data
  }

  depends_on = [google_container_cluster.primary]
}

resource "kubernetes_secret" "n8n_secret" {
  metadata {
    name      = "n8n-secret"
    namespace = "n8n"
  }

  data = {
    N8N_ENCRYPTION_KEY = data.google_secret_manager_secret_version.n8n_encryption_key.secret_data
  }

  depends_on = [google_container_cluster.primary]
}

resource "kubernetes_secret" "n8n_runners_secret" {
  metadata {
    name      = "n8n-runners-secret"
    namespace = "n8n"
  }

  data = {
    N8N_RUNNERS_AUTH_TOKEN = data.google_secret_manager_secret_version.n8n_runners_auth_token.secret_data
  }

  depends_on = [google_container_cluster.primary]
}

resource "kubernetes_secret" "affine_secret" {
  metadata {
    name      = "affine-secret"
    namespace = "affine"
  }

  data = {
    DB_PASSWORD          = data.google_secret_manager_secret_version.affine_db_password.secret_data
    NEXTAUTH_SECRET      = data.google_secret_manager_secret_version.affine_nextauth_secret.secret_data
    AFFINE_ADMIN_EMAIL   = data.google_secret_manager_secret_version.affine_admin_email.secret_data
    AFFINE_ADMIN_PASSWORD = data.google_secret_manager_secret_version.affine_admin_password.secret_data
  }

  depends_on = [kubernetes_namespace.affine]
}

resource "kubernetes_secret" "rag_secret" {
  metadata {
    name      = "rag-secret"
    namespace = "n8n"
  }

  data = {
    DB_PASSWORD = data.google_secret_manager_secret_version.rag_db_password.secret_data
  }

  depends_on = [google_container_cluster.primary]
}

resource "kubernetes_secret" "gemini_secret" {
  metadata {
    name      = "gemini-api-key"
    namespace = "n8n"
  }

  data = {
    api-key = data.google_secret_manager_secret_version.gemini_api_key.secret_data
  }

  depends_on = [google_container_cluster.primary]
}
