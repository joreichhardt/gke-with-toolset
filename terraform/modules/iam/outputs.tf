output "external_dns_gsa_email" { value = google_service_account.external_dns.email }
output "cert_manager_gsa_email" { value = google_service_account.cert_manager.email }
output "txt2md_app_gsa_email" { value = google_service_account.txt2md_app.email }
output "eso_gsa_email" { value = google_service_account.eso.email }
