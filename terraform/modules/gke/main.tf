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
  
  # Initialer Node Count
  initial_node_count = var.node_count

  # Dynamische Skalierung
  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

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

# Bereinigung verwaister PVC-Disks beim Destroy
resource "null_resource" "cleanup_pvc_disks" {
  triggers = {
    project_id = var.project_id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
      echo "🧹 Suche nach verwaisten GKE-Disks zum Löschen..."
      DISKS=$(gcloud compute disks list --project=${self.triggers.project_id} --filter="name:pvc-*" --format="value(name,zone)")
      if [ ! -z "$DISKS" ]; then
        echo "Lösche folgende Disks: $DISKS"
        while read -r name zone; do
          echo "Lösche verwaiste Disk $name in $zone..."
          gcloud compute disks delete "$name" --zone="$zone" --project=${self.triggers.project_id} --quiet || true
        done <<< "$DISKS"
      else
        echo "✅ Keine verwaisten Disks gefunden."
      fi
EOF
  }
}
