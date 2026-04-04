variable "project_id" {
  description = "GCP project ID where all resources are deployed"
  type        = string
}

variable "region" {
  description = "GCP region for all regional resources"
  type        = string
  default     = "europe-west3"
}

variable "env_name" {
  description = "Environment name, used as prefix for VPC and subnet names"
  type        = string
  default     = "prod"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "txt2md-cluster"
}

variable "node_count" {
  description = "Initial number of nodes per zone"
  type        = number
  default     = 1
}

variable "min_node_count" {
  description = "Minimum number of nodes per zone"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes per zone"
  type        = number
  default     = 5
}

variable "service_account_email" {
  description = "Email of the pre-existing GCP service account assigned to GKE nodes"
  type        = string
}

variable "repo_url" {
  description = "GitHub repository URL used as the ArgoCD source for the root app"
  type        = string
  default     = "https://github.com/joreichhardt/gke-with-toolset.git"
}

variable "gemini_api_key" {
  description = "Google Gemini API key, stored in GCP Secret Manager"
  type        = string
  sensitive   = true
}

variable "gitea_runner_token" {
  description = "Gitea Actions runner registration token, stored in GCP Secret Manager"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub personal access token for Gitea repository mirroring"
  type        = string
  sensitive   = true
}

variable "github_client_id" {
  description = "GitHub OAuth app client ID for Gitea SSO"
  type        = string
  sensitive   = true
}

variable "github_client_secret" {
  description = "GitHub OAuth app client secret for Gitea SSO"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Root domain for all platform services (e.g. example.com)"
  type        = string
  default     = "hannesalbeiro.com"
}

variable "acme_email" {
  description = "Email address for Let's Encrypt ACME certificate registration"
  type        = string
  default     = "johannes.reichhardt@gmail.com"
}
