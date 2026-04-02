variable "project_id" {
  type = string
}

variable "gemini_api_key" {
  type      = string
  sensitive = true
}

variable "gitea_runner_token" {
  type      = string
  sensitive = true
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "eso_gsa_email" {
  type = string
}
