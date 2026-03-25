# ── GKE Autopilot Cluster ─────────────────────────────────────────────────────
# Autopilot manages nodes automatically — we only pay for pod resource requests.
# No node pool resource needed.
resource "google_container_cluster" "primary" {
  name     = "n8n-cluster"
  location = var.region

  enable_autopilot    = true
  deletion_protection = false

  network    = google_compute_network.vpc.self_link
  subnetwork = google_compute_subnetwork.subnet.self_link

  release_channel {
    channel = var.gke_version
  }

  # Private cluster — nodes get no public IPs
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Keep public endpoint so kubectl works from your machine
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Lock down who can reach the GKE API
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.allowed_k3s_api_cidrs[0]
      display_name = "allowed-kubectl-access"
    }
  }

  ip_allocation_policy {
    # Let GKE auto-assign pod and service CIDRs
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}
