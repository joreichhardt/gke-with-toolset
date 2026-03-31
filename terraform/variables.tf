variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "project-84ddd43d-e408-4cb9-8cb"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "europe-west3" # Frankfurt
}

variable "cluster_name" {
  description = "Name of the GKE Cluster"
  type        = string
  default     = "txt2md-cluster"
}

variable "service_account_email" {
  description = "The service account email used for the nodes"
  type        = string
  default     = "terraform-sa@project-84ddd43d-e408-4cb9-8cb.iam.gserviceaccount.com"
}

variable "domain_name" {
  description = "The root domain for the cluster"
  type        = string
  default     = "hannesalbeiro.com"
}
