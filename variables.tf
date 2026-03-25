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
  description = "GCP machine type for K3s nodes"
  type        = string
  default     = "e2-medium"
}

variable "node_count" {
  description = "Number of agent nodes"
  type        = number
  default     = 2
}

variable "gke_version" {
  description = "GKE release channel"
  type        = string
  default     = "STABLE"
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