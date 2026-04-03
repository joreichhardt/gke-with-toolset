variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the subnetwork"
  type        = string
}

variable "env_name" {
  description = "Environment name used as prefix for VPC and subnet resource names"
  type        = string
}
