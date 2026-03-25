# ── GKE Cluster ───────────────────────────────────────────────────────────────
resource "google_container_cluster" "primary" {
  name     = "n8n-cluster"
  location = var.zone

  # We manage the node pool separately for flexibility
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.self_link
  subnetwork = google_compute_subnetwork.subnet.self_link

  # Use the STABLE release channel instead of pinning a version
  release_channel {
    channel = var.gke_version
  }

  # Private cluster — nodes get no public IPs
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Keep public endpoint so kubectl works from your machine
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Lock down who can hit the k3s API
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

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# ── Node Pool ─────────────────────────────────────────────────────────────────
resource "google_container_node_pool" "primary_nodes" {
  name     = "n8n-node-pool"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = 50
    disk_type    = "pd-standard"

    # Workload Identity on the nodes
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    tags = ["k3s-node"]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
