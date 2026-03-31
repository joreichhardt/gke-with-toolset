# Cloud-Native GKE Platform (hannesalbeiro.com)

A production-ready Kubernetes infrastructure featuring automated DNS, SSL, and full observability.

## 🏗️ Architecture & Features

This platform provides a highly scalable and secure environment:

- **GitOps & Tooling:** Argo CD, Grafana, Prometheus.
- **Auto-DNS & SSL:** Automatic subdomains via ExternalDNS and Cert-Manager (Let's Encrypt).
- **Traffic Management:** Modern Gateway API for routing.

## 🌐 Dashboard Access

Once deployed, access the services via these URLs:

- **Argo CD:** [https://argocd.hannesalbeiro.com](https://argocd.hannesalbeiro.com)
- **Grafana:** [https://grafana.hannesalbeiro.com](https://grafana.hannesalbeiro.com)
- **Prometheus:** [https://prometheus.hannesalbeiro.com](https://prometheus.hannesalbeiro.com)
- **txt2md App:** [https://txt2md.hannesalbeiro.com](https://txt2md.hannesalbeiro.com)

## 🚀 Initial Setup

1. **Terraform Apply:**
   ```bash
   cd terraform && terraform apply
   ```

2. **Cluster Access:**
   ```bash
   gcloud container clusters get-credentials txt2md-cluster --region europe-west3 --project project-84ddd43d-e408-4cb9-8cb
   ```

3. **Bootstrap Platform Manifests:**
   ```bash
   kubectl apply -f argocd/cert-manager-issuer.yaml
   kubectl apply -f argocd/platform-routes.yaml
   kubectl apply -f argocd/application.yaml
   ```

## 🔐 Credentials

- **Argo CD (admin):**
  `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
- **Grafana (admin):**
  `prom-operator` (initial password, change upon first login)
