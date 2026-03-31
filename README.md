# Cloud-Native GKE Platform

A production-ready Kubernetes infrastructure featuring automated DNS, SSL, and full observability, designed for maximum flexibility.

## 🏗️ Architecture & Features

This platform provides a highly scalable and secure environment:

- **GitOps & Tooling:** Argo CD, Grafana, Prometheus.
- **Auto-DNS & SSL:** Automatic subdomains via ExternalDNS and Cert-Manager (Let's Encrypt).
- **Traffic Management:** Modern Gateway API for routing.
- **Dynamic Configuration:** Domain and Project ID are fully variable.

## 🌐 Dashboard Access

Once deployed, access the services via these dynamically generated URLs:

- **Argo CD:** `https://argocd.${DOMAIN_NAME}`
- **Grafana:** `https://grafana.${DOMAIN_NAME}`
- **Prometheus:** `https://prometheus.${DOMAIN_NAME}`
- **txt2md App:** `https://txt2md.${DOMAIN_NAME}`

## 🚀 Initial Setup

### 1. Configuration
Adjust the variables in `terraform/variables.tf` to match your environment:
- `project_id`: Your GCP Project ID.
- `domain_name`: Your registered Google Cloud DNS domain.

### 2. Infrastructure Provisioning
```bash
cd terraform
terraform init
terraform apply
```

### 3. Cluster Connectivity
```bash
gcloud container clusters get-credentials txt2md-cluster --region europe-west3 --project YOUR_PROJECT_ID
```

### 4. Bootstrap Platform Manifests
Use the included bootstrap script to inject your variables into the Kubernetes manifests and deploy the platform services:
```bash
./bootstrap.sh
```

## 🔐 Credentials

- **Argo CD (admin):**
  `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
- **Grafana (admin):**
  `prom-operator` (initial password, change upon first login)

## 🛠️ Customization
To change the domain or project, simply update `terraform/variables.tf`, re-run `terraform apply`, and execute `./bootstrap.sh` again to synchronize the cluster state.
