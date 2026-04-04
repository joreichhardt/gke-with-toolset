resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = "txt2md-repo"
  format        = "DOCKER"

  lifecycle {
    prevent_destroy = false
  }
}

# Automatisierter Initial-Build (Bootstrap)
resource "null_resource" "bootstrap_image" {
  triggers = {
    repository_id = google_artifact_registry_repository.docker_repo.id
  }

  provisioner "local-exec" {
    command = "gcloud builds submit https://github.com/joreichhardt/txt2md.git --tag ${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}/txt2md:latest --project=${var.project_id}"
  }

  depends_on = [google_artifact_registry_repository.docker_repo]
}
