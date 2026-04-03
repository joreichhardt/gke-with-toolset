resource "google_secret_manager_secret" "gemini_key" {
  secret_id = "gemini-api-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "gemini_key_v1" {
  secret      = google_secret_manager_secret.gemini_key.id
  secret_data = var.gemini_api_key
}

# Allow ESO to read this secret
resource "google_secret_manager_secret_iam_member" "eso_secret_reader" {
  secret_id = google_secret_manager_secret.gemini_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.eso_gsa_email}"
}

# Flask Secret managed in Secret Manager
resource "random_password" "flask_secret" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "flask_secret" {
  secret_id = "flask-secret-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "flask_secret_v1" {
  secret      = google_secret_manager_secret.flask_secret.id
  secret_data = random_password.flask_secret.result
}

resource "google_secret_manager_secret_iam_member" "eso_flask_reader" {
  secret_id = google_secret_manager_secret.flask_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.eso_gsa_email}"
}

# Gitea Runner Token managed in Secret Manager
resource "google_secret_manager_secret" "gitea_token" {
  secret_id = "gitea-runner-token"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "gitea_token_v1" {
  secret      = google_secret_manager_secret.gitea_token.id
  secret_data = var.gitea_runner_token
}

resource "google_secret_manager_secret_iam_member" "eso_gitea_reader" {
  secret_id = google_secret_manager_secret.gitea_token.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.eso_gsa_email}"
}

# GitHub Token managed in Secret Manager
resource "google_secret_manager_secret" "github_token" {
  secret_id = "github-token"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "github_token_v1" {
  secret      = google_secret_manager_secret.github_token.id
  secret_data = var.github_token
}

resource "google_secret_manager_secret_iam_member" "eso_github_reader" {
  secret_id = google_secret_manager_secret.github_token.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.eso_gsa_email}"
}

# GitHub OAuth Client ID
resource "google_secret_manager_secret" "github_client_id" {
  secret_id = "github-client-id"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "github_client_id_v1" {
  secret      = google_secret_manager_secret.github_client_id.id
  secret_data = var.github_client_id
}

resource "google_secret_manager_secret_iam_member" "eso_github_client_id_reader" {
  secret_id = google_secret_manager_secret.github_client_id.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.eso_gsa_email}"
}

# GitHub OAuth Client Secret
resource "google_secret_manager_secret" "github_client_secret" {
  secret_id = "github-client-secret"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "github_client_secret_v1" {
  secret      = google_secret_manager_secret.github_client_secret.id
  secret_data = var.github_client_secret
}

resource "google_secret_manager_secret_iam_member" "eso_github_client_secret_reader" {
  secret_id = google_secret_manager_secret.github_client_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.eso_gsa_email}"
}
