output "cloudsql_private_ip" {
  description = "Private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.n8n.private_ip_address
}

output "gke_cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "gke_cluster_endpoint" {
  description = "Endpoint of the GKE cluster"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}
