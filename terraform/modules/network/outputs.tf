output "network_id" { value = google_compute_network.main.id }
output "subnet_id" { value = google_compute_subnetwork.gke_subnet.id }
