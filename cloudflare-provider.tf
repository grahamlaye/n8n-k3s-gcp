# ── Cloudflare Provider ───────────────────────────────────────────────────────
# API token is read from GCP Secret Manager at apply time — never stored on disk.
# To create the secret:
#   gcloud secrets create cloudflare-api-token --project=n8n-demo-lab
#   echo -n "cfat_..." | gcloud secrets versions add cloudflare-api-token \
#     --data-file=- --project=n8n-demo-lab

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
  default     = "59d9e23e41c0cd9ebba67bc448297dc0"
}

provider "cloudflare" {
  api_token = data.google_secret_manager_secret_version.cloudflare_api_token.secret_data
}
