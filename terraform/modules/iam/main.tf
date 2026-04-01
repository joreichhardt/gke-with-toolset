# GSA for ExternalDNS
resource "google_service_account" "external_dns" {
  account_id   = "external-dns-gsa"
  display_name = "GSA for ExternalDNS"
}

resource "google_project_iam_member" "dns_admin" {
  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.external_dns.email}"
}

resource "google_service_account_iam_member" "external_dns_wi" {
  service_account_id = google_service_account.external_dns.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[kube-system/external-dns]"
}

# GSA for Cert-Manager
resource "google_service_account" "cert_manager" {
  account_id   = "cert-manager-gsa"
  display_name = "GSA for Cert-Manager"
}

resource "google_project_iam_member" "dns_solver" {
  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.cert_manager.email}"
}

resource "google_service_account_iam_member" "cert_manager_wi" {
  service_account_id = google_service_account.cert_manager.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[cert-manager/cert-manager]"
}

# GSA for txt2md App (to read secrets)
resource "google_service_account" "txt2md_app" {
  account_id   = "txt2md-app-gsa"
  display_name = "GSA for txt2md Application"
}

resource "google_service_account_iam_member" "txt2md_wi" {
  service_account_id = google_service_account.txt2md_app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/txt2md-sa]"
}

# GSA for External Secrets Operator (to read all secrets)
resource "google_service_account" "eso" {
  account_id   = "eso-gsa"
  display_name = "GSA for External Secrets Operator"
}

resource "google_project_iam_member" "eso_secret_reader" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.eso.email}"
}

resource "google_service_account_iam_member" "eso_wi" {
  service_account_id = google_service_account.eso.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[external-secrets/external-secrets-sa]"
}
