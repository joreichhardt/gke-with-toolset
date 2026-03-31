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
  node_count = 1 # 1 node per zone * 3 zones = 3 nodes total

  node_config {
    preemptible  = true
    machine_type = "e2-standard-2" # 2 vCPUs, 8GB RAM - Total 6 vCPUs

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

  lifecycle {
    prevent_destroy = true
  }
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

  set {
    name  = "server.extraArgs"
    value = "{--insecure}"
  }
}

# 4. Cert-Manager (SSL)
resource "google_service_account_iam_member" "cert_manager_workload_identity" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[cert-manager/cert-manager]"
}

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
  set {
    name  = "serviceAccount.annotations.iam\\.gke\\.io/gcp-service-account"
    value = var.service_account_email
  }
}

# 5. External DNS (Cloud DNS Sync)
resource "google_service_account_iam_member" "external_dns_workload_identity" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[kube-system/external-dns]"
}

resource "google_project_iam_member" "external_dns_dns_admin" {
  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${var.service_account_email}"
}

resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  namespace        = "kube-system"
  version          = "1.13.1"
  
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }
  set {
    name  = "serviceAccount.annotations.iam\\.gke\\.io/gcp-service-account"
    value = var.service_account_email
  }
  set {
    name  = "provider"
    value = "google"
  }
  set {
    name  = "sources"
    value = "{service,ingress,gateway-httproute}"
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

# --- APPLICATION SECRETS ---

resource "random_password" "flask_secret" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "txt2md_secrets" {
  metadata {
    name      = "txt2md-secrets"
    namespace = "default"
  }

  data = {
    "ai-api-key"       = var.gemini_api_key
    "flask-secret-key" = random_password.flask_secret.result
  }

  depends_on = [google_container_cluster.primary]
}

# --- SECURE PLATFORM CONFIGURATION ---
# We use a null_resource to apply manifests via kubectl because the official 
# kubernetes_manifest provider fails if CRDs are not present during plan/apply.

resource "null_resource" "apply_platform_manifests" {
  depends_on = [
    google_container_cluster.primary,
    helm_release.cert_manager,
    helm_release.argocd,
    helm_release.monitoring
  ]

  provisioner "local-exec" {
    command = <<EOT
      gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.project_id}
      
      # Wait a few seconds for CRDs to be fully recognized by the API
      sleep 30
      
      cat <<EOF > platform_generated.yaml
${templatefile("${path.module}/manifests/platform.yaml.tpl", {
  domain_name = var.domain_name
  project_id  = var.project_id
})}
EOF
      kubectl apply -f platform_generated.yaml

      # Bootstrap the Argo CD Application for txt2md
      cat <<EOF > argocd_app_generated.yaml
${templatefile("${path.module}/../argocd/application.yaml", {
  # Wir nutzen hier die Variablen, falls sie im Manifest Platzhalter hätten
})}
EOF
      # Hinweis: Da das application.yaml aktuell noch statisch ist, 
      # wenden wir es einfach direkt an:
      kubectl apply -f ../argocd/application.yaml
    EOT
  }

  triggers = {
    manifest_sha1 = sha1(templatefile("${path.module}/manifests/platform.yaml.tpl", {
      domain_name = var.domain_name
      project_id  = var.project_id
    }))
  }
}
