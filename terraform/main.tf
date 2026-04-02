module "network" {
  source     = "./modules/network"
  project_id = var.project_id
  region     = var.region
  env_name   = var.env_name
}

module "iam" {
  source     = "./modules/iam"
  project_id = var.project_id
  region     = var.region
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

module "secrets" {
  source               = "./modules/secrets"
  project_id           = var.project_id
  gemini_api_key       = var.gemini_api_key
  gitea_runner_token   = var.gitea_runner_token
  github_token         = var.github_token
  github_client_id     = var.github_client_id
  github_client_secret = var.github_client_secret
  eso_gsa_email        = module.iam.eso_gsa_email
}

module "registry" {
  source     = "./modules/artifact_registry"
  project_id = var.project_id
  region     = var.region
}

module "argocd" {
  source      = "./modules/argocd"
  repo_url    = var.repo_url
  domain_name = var.domain_name
  acme_email  = var.acme_email
  project_id  = var.project_id
  
  depends_on = [module.gke]
}
