module "network" {
  source     = "./modules/network"
  project_id = var.project_id
  region     = var.region
  env_name   = var.env_name
}

module "gke" {
  source                = "./modules/gke"
  project_id            = var.project_id
  region                = var.region
  cluster_name          = var.cluster_name
  network_id            = module.network.network_id
  subnet_id             = module.network.subnet_id
  service_account_email = var.service_account_email
}

module "registry" {
  source     = "./modules/artifact_registry"
  project_id = var.project_id
  region     = var.region
}

module "argocd" {
  source   = "./modules/argocd"
  repo_url = var.repo_url
  
  # Dependent on GKE module
  depends_on = [module.gke]
}

module "observability" {
  source     = "./modules/observability"
  depends_on = [module.gke]
}

# IAM bindings (could also be a separate module)
resource "google_service_account_iam_member" "external_dns_wi" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[kube-system/external-dns]"
}

resource "google_project_iam_member" "dns_admin" {
  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${var.service_account_email}"
}

resource "google_service_account_iam_member" "cert_manager_wi" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[cert-manager/cert-manager]"
}

# Application Secrets
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
  depends_on = [module.gke]
}
