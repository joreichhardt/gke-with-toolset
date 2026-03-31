# Cloud-Native GKE Platform

A fully autonomous Kubernetes infrastructure on GCP featuring automated DNS, SSL, GitOps, and observability. This setup is designed for persistence and ease of redeployment.

## 🏗️ Architecture & Features

This platform is managed as a single unit via Terraform:

- **Infrastructure:** GKE Cluster with Workload Identity and Gateway API.
- **GitOps:** Argo CD for automated application lifecycle management.
- **Auto-DNS & SSL:** Automatic subdomains and HTTPS via ExternalDNS and Cert-Manager.
- **Persistence:** **Artifact Registry** is protected from accidental deletion (`prevent_destroy`).
- **Secret Management:** Sensitive API keys are managed via Terraform variables and automated K8s Secrets.

## 🌐 Automated Subdomains

Once deployed, all services are automatically reachable via:
- **Argo CD:** `https://argocd.${DOMAIN_NAME}`
- **Grafana:** `https://grafana.${DOMAIN_NAME}`
- **Prometheus:** `https://prometheus.${DOMAIN_NAME}`
- **txt2md App:** `https://txt2md.${DOMAIN_NAME}`

## 🚀 Deployment

### 1. Configuration
1. Set your project and domain in `terraform/variables.tf`.
2. Create a `terraform/terraform.tfvars` file to store your sensitive keys (this file is ignored by Git):
   ```hcl
   gemini_api_key = "your-api-key-here"
   ```

### 2. Apply Infrastructure
```bash
cd terraform
terraform init
terraform apply
```
*Wait ~15 minutes for the cluster and all platform services to be fully ready.*

### 3. Build & Push Application (First time only)
Since the Registry is protected, you only need to push the image once or when you have updates:
```bash
cd ../txt2md
docker build -t europe-west3-docker.pkg.dev/${PROJECT_ID}/txt2md-repo/txt2md:v1.0.1 .
docker push europe-west3-docker.pkg.dev/${PROJECT_ID}/txt2md-repo/txt2md:v1.0.1
```

## 🔐 Access Credentials

- **Argo CD (admin):**
  `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
- **Grafana (admin):**
  `prom-operator` (initial password, change upon first login)

## 🛠️ Disaster Recovery & Destroy
- Running `terraform destroy` will delete the cluster and toolset but **keep the Artifact Registry** intact.
- Upon the next `terraform apply`, the cluster will be rebuilt, the secrets will be re-created, and Argo CD will automatically pull the existing image from the Registry.
