terraform {
  required_version = ">= 1.0.0"
  backend "gcs" {
    bucket = "project-84ddd43d-e408-4cb9-8cb-k3s-tf-state"
    prefix = "terraform/state/gke-platform"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.22"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# 1. GKE Cluster mit Workload Identity & Gateway API
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 3

  node_config {
    preemptible  = true
    machine_type = "e2-standard-4" # Größer für Monitoring Stack (Prometheus/Grafana)

    service_account = var.service_account_email
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

# 2. Artifact Registry
resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = "txt2md-repo"
  format        = "DOCKER"
}

# Providers für K8s & Helm
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  }
}

# 3. Argo CD
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.46.7"
}

# 4. Cert-Manager (SSL)
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.13.1"
  set {
    name  = "installCRDs"
    value = "true"
  }
}

# 5. External DNS (Cloud DNS Sync)
resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  namespace        = "kube-system"
  version          = "1.13.1"
  set {
    name  = "provider"
    value = "google"
  }
  set {
    name  = "domainFilters[0]"
    value = var.domain_name
  }
  set {
    name  = "google.project"
    value = var.project_id
  }
}

# 6. Monitoring (Prometheus & Grafana)
resource "helm_release" "monitoring" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "51.2.0"
}

# --- AUTOMATED KUBERNETES CONFIGURATION ---

# Cert-Manager ClusterIssuer
resource "kubernetes_manifest" "letsencrypt_issuer" {
  depends_on = [helm_release.cert_manager]
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = "hannes@${var.domain_name}"
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [
          {
            dns01 = {
              cloudDNS = {
                project = var.project_id
              }
            }
          }
        ]
      }
    }
  }
}

# Main Gateway
resource "kubernetes_manifest" "main_gateway" {
  depends_on = [google_container_cluster.primary]
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "Gateway"
    metadata = {
      name      = "main-gateway"
      namespace = "default"
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      }
    }
    spec = {
      gatewayClassName = "gke-l7-global-external-managed"
      listeners = [
        {
          name     = "https"
          protocol = "HTTPS"
          port     = 443
          hostname = "*.${var.domain_name}"
          tls = {
            mode = "Terminate"
            certificateRefs = [
              {
                name = "main-cert"
              }
            ]
          }
        }
      ]
    }
  }
}

# HTTPRoutes for Toolset
resource "kubernetes_manifest" "platform_routes" {
  for_each = {
    "argocd"     = { ns = "argocd", svc = "argocd-server", port = 80 }
    "grafana"    = { ns = "monitoring", svc = "monitoring-grafana", port = 80 }
    "prometheus" = { ns = "monitoring", svc = "monitoring-kube-prometheus-prometheus", port = 9090 }
  }

  depends_on = [kubernetes_manifest.main_gateway, helm_release.argocd, helm_release.monitoring]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "${each.key}-route"
      namespace = each.value.ns
    }
    spec = {
      parentRefs = [
        {
          name      = "main-gateway"
          namespace = "default"
        }
      ]
      hostnames = ["${each.key}.${var.domain_name}"]
      rules = [
        {
          backendRefs = [
            {
              name = each.value.svc
              port = each.value.port
            }
          ]
        }
      ]
    }
  }
}
