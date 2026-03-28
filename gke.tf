# ── GKE Standard Cluster ──────────────────────────────────────────────────────
resource "google_container_cluster" "primary" {
  name     = "n8n-cluster"
  location = var.zone

  # We manage the node pool separately for full control
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.self_link
  subnetwork = google_compute_subnetwork.subnet.self_link

  release_channel {
    channel = var.gke_version
  }

  # Private cluster — nodes get no public IPs
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Lock down who can reach the GKE API
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.allowed_k3s_api_cidrs
      content {
        cidr_block   = cidr_blocks.value
        display_name = "allowed-kubectl-access-${cidr_blocks.key}"
      }
    }
  }

  ip_allocation_policy {
    # Let GKE auto-assign pod and service CIDRs
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Disable Managed Prometheus — we'll run our own
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = false
    }
  }

  # Reduce logging to system components only
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  deletion_protection = false
}

# ── Node Pool ─────────────────────────────────────────────────────────────────
resource "google_container_node_pool" "primary_nodes" {
  name     = "n8n-node-pool"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  # Cluster autoscaler — idles at 1 node, scales to 3 under load
  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = 50
    disk_type    = "pd-standard"

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    tags = ["gke-n8n-node"]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
