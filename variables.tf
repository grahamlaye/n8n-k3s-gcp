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

variable "gke_version" {
  description = "GKE release channel"
  type        = string
  default     = "STABLE"
}

variable "allowed_ssh_cidrs" {
  description = "CIDR ranges allowed to SSH into nodes"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Override in terraform.tfvars with your IP
}

variable "allowed_k3s_api_cidrs" {
  description = "CIDR ranges allowed to reach the k3s API (kubectl)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Override in terraform.tfvars with your IP
}