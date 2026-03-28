variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "n8n-demo-lab"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west2"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "europe-west2-a"
}

variable "machine_type" {
  description = "GCP machine type for GKE nodes"
  type        = string
  default     = "e2-medium"
}

variable "min_node_count" {
  description = "Minimum nodes per zone (autoscaling)"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum nodes per zone (autoscaling)"
  type        = number
  default     = 3
}

variable "gke_version" {
  description = "GKE release channel"
  type        = string
  default     = "STABLE"
}

variable "db_version" {
  description = "Cloud SQL Postgres version"
  type        = string
  default     = "POSTGRES_15"
}

variable "allowed_k3s_api_cidrs" {
  description = "CIDR ranges allowed to reach the k3s API (kubectl)"
  type        = list(string)
  default     = ["82.14.69.238/32", "150.228.9.108/32"]
}

variable "allowed_web_cidrs" {
  description = "CIDRs allowed to reach HTTP/HTTPS — Cloudflare IPv4 ranges plus home IP"
  type        = list(string)
  default = [
    # Home IP — direct access for troubleshooting
    "82.14.69.238/32",
    # Cloudflare IPv4 ranges (https://www.cloudflare.com/ips-v4)
    "173.245.48.0/20",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "141.101.64.0/18",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
    "162.158.0.0/15",
    "104.16.0.0/13",
    "104.24.0.0/14",
    "172.64.0.0/13",
    "131.0.72.0/22",
  ]
}