# Cloud-Native GKE Platform

A production-ready Kubernetes infrastructure on Google Cloud Platform (GCP) featuring GitOps, automated SSL, DNS synchronization, and full-stack observability.

## 🏗️ Architecture & Features

This platform provides a highly scalable and secure environment for modern applications:

- **Infrastructure:** GKE Cluster with Workload Identity enabled for secure GCP service access without static keys.
- **Node Configuration:** 3 x `e2-standard-4` nodes (preemptible) providing high performance and cost-efficiency.
- **GitOps:** Argo CD managed deployment workflow for automated synchronization between GitHub and Cluster state.
- **Network & Traffic:** 
  - **Gateway API:** Modern traffic management for GKE.
  - **ExternalDNS:** Automatic synchronization of Kubernetes resources with Google Cloud DNS (`hannesalbeiro.com`).
  - **Cert-Manager:** Automated SSL certificate provisioning via Let's Encrypt (DNS-01 challenge).
- **Observability:** Complete monitoring stack using Prometheus and Grafana for real-time performance insights.
- **Registry:** Private Google Artifact Registry for secure container image storage.

## 📋 Prerequisites

- **Google Cloud SDK (`gcloud`)**
- **Terraform** (>= 1.0.0)
- **kubectl**
- **Helm** (optional, for local manual testing)

## 🚀 Deployment Guide

### 1. Provision Infrastructure
Initialize and apply the Terraform configuration:
```bash
cd terraform
terraform init
terraform apply
```

### 2. Cluster Connectivity
Configure your local environment to interact with the new cluster:
```bash
gcloud container clusters get-credentials txt2md-cluster --region europe-west3 --project project-84ddd43d-e408-4cb9-8cb
```

### 3. Deploy Platform Toolset
The platform uses Argo CD to manage its own components. Apply the initial application definitions:
```bash
kubectl apply -f argocd/application.yaml
```

## 🔐 Credentials & Access

### Argo CD UI
1. Retrieve the LoadBalancer IP:
   ```bash
   kubectl get svc argocd-server -n argocd
   ```
2. Get the initial admin password:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

### Grafana Dashboards
1. Port-forward the service:
   ```bash
   kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
   ```
2. Access via `http://localhost:3000` (Default: admin/prom-operator).

## 🛠️ Application Deployment Workflow

1. Push your Docker image to the Artifact Registry: `europe-west3-docker.pkg.dev/project-84ddd43d-e408-4cb9-8cb/txt2md-repo/txt2md:latest`
2. Update the Kubernetes manifests in your application repository.
3. Argo CD will automatically detect the changes and sync the deployment.

## 📄 License
This project is licensed under the MIT License.
