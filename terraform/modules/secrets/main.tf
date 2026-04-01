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
