# Cloud-Native GKE Platform

A fully autonomous Kubernetes infrastructure on GCP featuring automated DNS, SSL, GitOps, and observability.

## 🏗️ Architecture & Features

This platform is deployed as a single unit via Terraform:

- **GitOps:** Argo CD for application lifecycle management.
- **Auto-DNS & SSL:** Automatic subdomains and HTTPS via ExternalDNS and Cert-Manager.
- **Observability:** Full Prometheus & Grafana stack.
- **Modern Networking:** GKE Gateway API for efficient traffic routing.

## 🌐 Automated Subdomains

The following services are automatically provisioned and reachable via:
- **Argo CD:** `https://argocd.${DOMAIN_NAME}`
- **Grafana:** `https://grafana.${DOMAIN_NAME}`
- **Prometheus:** `https://prometheus.${DOMAIN_NAME}`
- **txt2md App:** `https://txt2md.${DOMAIN_NAME}`

## 🚀 Deployment

### 1. Configure
Set your project and domain in `terraform/variables.tf`.

### 2. Apply Infrastructure
```bash
cd terraform
terraform init
terraform apply
```
*Wait ~15 minutes for the cluster and all platform services to be fully ready.*

### 3. Connect
```bash
gcloud container clusters get-credentials txt2md-cluster --region europe-west3 --project YOUR_PROJECT_ID
```

## 🔐 Access Credentials

- **Argo CD (admin):**
  `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
- **Grafana (admin):**
  `prom-operator` (initial password, change upon first login)
