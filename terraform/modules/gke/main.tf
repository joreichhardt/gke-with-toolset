resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  network    = var.network_id
  subnetwork = var.subnet_id

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }
}

resource "google_container_node_pool" "nodes" {
  name       = "${var.cluster_name}-node-pool"
  cluster    = google_container_cluster.primary.name
  location   = var.region
  node_count = var.node_count

  node_config {
    preemptible  = true
    machine_type = var.machine_type
    service_account = var.service_account_email
    
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}
