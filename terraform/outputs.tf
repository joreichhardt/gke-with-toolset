output "cluster_name" {
  value = module.gke.cluster_name
}

output "cluster_endpoint" {
  value = module.gke.cluster_endpoint
}

output "artifact_registry_repo" {
  value = module.registry.artifact_registry_repo
}

output "argocd_url" {
  value = "https://argocd.${var.domain_name}"
}

output "get_credentials_command" {
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id}"
  description = "Run this command to update your local kubeconfig"
}
