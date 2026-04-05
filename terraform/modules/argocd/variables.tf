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

variable "cluster_name" {
  description = "GKE cluster name, used to configure kubectl in local-exec provisioners"
  type        = string
}

variable "region" {
  description = "GCP region of the GKE cluster"
  type        = string
}

variable "cert_bucket" {
  description = "GCS bucket name used to store and restore TLS certificate secrets"
  type        = string
}
