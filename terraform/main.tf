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
  service_account_email = var.service_account_email # Still used for Node GSA
}

module "iam" {
  source     = "./modules/iam"
  project_id = var.project_id
  region     = var.region
}

module "secrets" {
  source         = "./modules/secrets"
  project_id     = var.project_id
  gemini_api_key = var.gemini_api_key
  eso_gsa_email  = module.iam.eso_gsa_email
}

module "registry" {
  source     = "./modules/artifact_registry"
  project_id = var.project_id
  region     = var.region
}

module "argocd" {
  source   = "./modules/argocd"
  repo_url = var.repo_url
  depends_on = [module.gke]
}

module "observability" {
  source     = "./modules/observability"
  depends_on = [module.gke]
}

# The kubernetes_secret for txt2md is now DEPRECATED. 
# We use GCP Secret Manager + ESO instead.
# However, we keep the random password for flask_secret for now, 
# but move it to Secret Manager later for 100% production grade.
resource "random_password" "flask_secret" {
  length  = 32
  special = false
}
