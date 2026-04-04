# Cloud-Native GKE Platform

A fully autonomous Kubernetes infrastructure on GCP featuring automated DNS, SSL, GitOps, and a complete CI/CD pipeline. This setup is designed for persistence and ease of redeployment.  

terraform apply takes about 20 Minutes. Till the Gateway gets an IP another 10 to 15

## 🏗️ Architecture & Features

This platform is managed as a single unit via Terraform and Argo CD:

- **Infrastructure:** GKE Autopilot Cluster with Workload Identity and Gateway API.
- **GitOps:** Argo CD for automated application lifecycle management.
- **CI/CD:** **Gitea** (hosted on-cluster) with **Gitea Actions (Runner)** for automated Docker builds.
- **Auto-DNS & SSL:** Automatic subdomains and HTTPS via ExternalDNS and Cert-Manager (Let's Encrypt).
- **Network:** Global L7 Load Balancer with **automatic HTTP-to-HTTPS redirection**.
- **Persistence:** Artifact Registry is protected from accidental deletion (`prevent_destroy`).
- **Secret Management:** Google Secret Manager integrated with External Secrets Operator (ESO).

## 🌐 Automated Subdomains

Once deployed, all services are automatically reachable via HTTPS:
- **Gitea (Git & CI):** `https://gitea.${DOMAIN_NAME}`
- **Argo CD (GitOps):** `https://argocd.${DOMAIN_NAME}`
- **Grafana (Monitoring):** `https://grafana.${DOMAIN_NAME}`
- **txt2md App:** `https://txt2md.${DOMAIN_NAME}`

## 🚀 CI/CD Pipeline Flow

1. **Push:** You push code to GitHub.
2. **Mirror:** Gitea mirrors the GitHub repository in real-time (via Webhook).
3. **Build:** A Gitea Action (`.gitea/workflows/build.yaml`) triggers on the internal runner.
4. **Push:** The runner builds the Docker image and pushes it to Google Artifact Registry using Workload Identity.
5. **Deploy:** **Argo CD Image Updater** detects the new image version, updates the manifest in Gitea, and triggers a rolling update in the GKE cluster.

## 🔐 Access & Credentials

### Argo CD
- **URL:** `https://argocd.${DOMAIN_NAME}`
- **Username:** `admin`
- **Password:** `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo`

### Gitea
- **URL:** `https://gitea.${DOMAIN_NAME}`
- **Username:** `gitea_admin`
- **Password:** `kubectl -n gitea-ci get secret gitea-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo`

### Grafana (Monitoring)
- **URL:** `https://grafana.${DOMAIN_NAME}`
- **Username:** `admin`
- **Password:** `kubectl -n monitoring get secret grafana-admin-secret -o jsonpath="{.data.admin-password}" | base64 -d; echo`

## 🛠️ Deployment

### 1. Terraform Infrastructure
```bash
cd terraform
terraform init
terraform apply
```

#### Node Scaling & Cluster Configuration
You can control the cluster name, size and automatic scaling via `terraform.tfvars`:
```hcl
cluster_name   = "txt2md-cluster" # Custom name for your GKE cluster
node_count     = 1               # Initial nodes per zone
min_node_count = 1               # Minimum nodes per zone (autoscaling)
max_node_count = 5               # Maximum nodes per zone (autoscaling)
```
The cluster will automatically add nodes if the workload (e.g. Monitoring or CI/CD jobs) exceeds the current capacity.

### 2. Gitea Runner Registration
After Gitea is up, retrieve the registration token from **Site Admin -> Actions -> Runners**, update your `terraform.tfvars` with `gitea_runner_token = "YOUR_TOKEN"`, and run `terraform apply` again. The External Secrets Operator will then automatically sync it to the runner.

## 🛡️ Disaster Recovery & Destroy
- Running `terraform destroy` will delete the cluster and toolset but **keep the Artifact Registry** intact.
- Upon the next `terraform apply`, the cluster will be rebuilt, and Argo CD will automatically restore the entire platform state from the Git manifests.
