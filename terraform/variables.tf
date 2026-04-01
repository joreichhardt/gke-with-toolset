variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-west3"
}

variable "env_name" {
  type    = string
  default = "prod"
}

variable "cluster_name" {
  type    = string
  default = "txt2md-cluster"
}

variable "service_account_email" {
  type = string
}

variable "repo_url" {
  type    = string
  default = "https://github.com/joreichhardt/gke-with-toolset.git"
}

variable "gemini_api_key" {
  type      = string
  sensitive = true
}
