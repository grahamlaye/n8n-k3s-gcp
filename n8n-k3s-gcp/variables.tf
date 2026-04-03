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
  default     = 1
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
  description = "CIDR ranges allowed to reach the GKE API (kubectl)"
  type        = list(string)
  default     = [
    "35.214.53.241/32", # GKE NAT egress — WARP kubectl traffic exits here
  ]
}
