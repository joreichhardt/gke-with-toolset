resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = "txt2md-repo"
  format        = "DOCKER"

  lifecycle {
    prevent_destroy = false
  }
}
