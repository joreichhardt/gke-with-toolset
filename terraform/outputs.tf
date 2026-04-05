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

output "argocd_password_command" {
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
  description = "Run this command to get the initial ArgoCD admin password"
}

output "gitea_password_command" {
  value       = "gcloud secrets versions access latest --secret='gitea-admin-password' --project=${var.project_id}"
  description = "Run this command to get the Gitea admin password from Secret Manager"
}

output "grafana_password_command" {
  value       = "gcloud secrets versions access latest --secret='grafana-admin-password' --project=${var.project_id}"
  description = "Run this command to get the Grafana admin password from Secret Manager"
}
