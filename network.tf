# ── Project Network Tier ─────────────────────────────────────────────────────
resource "google_compute_project_default_network_tier" "default" {
  network_tier = "STANDARD"
}

# ── VPC ──────────────────────────────────────────────────────────────────────
resource "google_compute_network" "vpc" {
  name                    = "n8n-vpc"
  auto_create_subnetworks = false
}

# ── Subnet ────────────────────────────────────────────────────────────────────
resource "google_compute_subnetwork" "subnet" {
  name                     = "n8n-subnet"
  ip_cidr_range            = "10.10.0.0/24"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

# ── Private Services Access (required for Cloud SQL private IP) ───────────────
resource "google_compute_global_address" "private_services_range" {
  name          = "n8n-private-services-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services_range.name]
}

# ── Firewall Rules ────────────────────────────────────────────────────────────

# k3s API server (kubectl access)
resource "google_compute_firewall" "allow_k3s_api" {
  name    = "n8n-allow-k3s-api"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

  source_ranges = var.allowed_k3s_api_cidrs
  target_tags   = ["gke-n8n-node"]
}

# HTTP/HTTPS for n8n ingress
resource "google_compute_firewall" "allow_web" {
  name    = "n8n-allow-web"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gke-n8n-node"]
}

# Inter-node communication (k3s flannel, etcd, etc.)
resource "google_compute_firewall" "allow_internal" {
  name    = "n8n-allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.10.0.0/24"]
  target_tags   = ["gke-n8n-node"]
}

# GCP health check probes (for load balancer)
resource "google_compute_firewall" "allow_health_checks" {
  name    = "n8n-allow-health-checks"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["gke-n8n-node"]
}
