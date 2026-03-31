output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  value = google_container_cluster.primary.endpoint
}

output "artifact_registry_repo" {
  value = google_artifact_registry_repository.docker_repo.name
}

output "argocd_server_address" {
  value = "Check with: kubectl get svc argocd-server -n argocd"
}
