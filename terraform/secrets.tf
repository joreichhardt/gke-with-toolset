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
