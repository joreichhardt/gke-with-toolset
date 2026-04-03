variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the cluster"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "network_id" {
  description = "Self-link of the VPC network"
  type        = string
}

variable "subnet_id" {
  description = "Self-link of the GKE subnetwork"
  type        = string
}

variable "node_count" {
  description = "Number of nodes per zone in the node pool"
  type        = number
  default     = 1
}

variable "machine_type" {
  description = "GCE machine type for cluster nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "service_account_email" {
  description = "Email of the GCP service account assigned to cluster nodes"
  type        = string
}
