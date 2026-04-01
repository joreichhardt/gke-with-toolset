terraform {
  required_version = ">= 1.0.0"
  backend "gcs" {
    bucket = "project-84ddd43d-e408-4cb9-8cb-k3s-tf-state"
    prefix = "terraform/state/gke-platform"
  }
  required_providers {
    google = { source = "hashicorp/google"; version = "~> 5.0" }
    helm   = { source = "hashicorp/helm"; version = "~> 2.10" }
    kubernetes = { source = "hashicorp/kubernetes"; version = "~> 2.22" }
    random = { source = "hashicorp/random"; version = "~> 3.0" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Data from GKE module
provider "kubernetes" {
  host                   = "https://${module.gke.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.cluster_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
  }
}

data "google_client_config" "default" {}
