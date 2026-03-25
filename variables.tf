variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "260949299205"
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

variable "k3s_version" {
  description = "K3s version to install"
  type        = string
  default     = "v1.29.3+k3s1"
}

variable "ssh_user" {
  description = "SSH username for GCE instances"
  type        = string
  default     = "ubuntu"
}

variable "ssh_pub_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}