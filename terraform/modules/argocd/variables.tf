variable "repo_url" {
  description = "GitHub repository URL used as the ArgoCD bootstrap source"
  type        = string
}

variable "domain_name" {
  description = "Root domain for all platform services"
  type        = string
}

variable "acme_email" {
  description = "Email for Let's Encrypt ACME registration"
  type        = string
}

variable "project_id" {
  description = "GCP project ID, passed through to the root ArgoCD Application"
  type        = string
}
