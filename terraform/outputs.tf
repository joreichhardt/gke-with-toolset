output "cluster_name" {
  value = module.gke.cluster_name
}

output "cluster_endpoint" {
  value = module.gke.cluster_endpoint
}

output "artifact_registry_repo" {
  value = module.registry.artifact_registry_repo
}

output "argocd_server_address" {
  value = "Check with: kubectl get svc argocd-server -n argocd"
}
