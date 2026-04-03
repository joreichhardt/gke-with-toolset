# Platform Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove dead code, fix broken template syntax, parameterize hardcoded values, and secure the Grafana password across the GKE platform repo.

**Architecture:** Pure config/manifest changes — Terraform HCL and Kubernetes/Helm YAML. No application code. Verification via `terraform validate`, `helm lint`, and `helm template`.

**Tech Stack:** Terraform ~> 5.0 (google provider), Helm, ArgoCD, Kubernetes, GCP Secret Manager, External Secrets Operator

---

## File Map

| File | Change |
|------|--------|
| `terraform/modules/secrets/main.tf` | Remove backstage resources; add grafana-admin-password secret |
| `terraform/modules/observability/` | Delete entire directory |
| `terraform/variables.tf` | Add descriptions; tighten `required_version` |
| `terraform/providers.tf` | Tighten `required_version` |
| `terraform/modules/*/variables.tf` | Add descriptions to all module variable files |
| `platform/external-dns/values.yaml` | Remove Helm template syntax |
| `platform/cert-manager/values.yaml` | Remove hardcoded service account annotation |
| `platform/bootstrap/templates/app-infrastructure.yaml` | Add cert-manager SA annotation as `helm.parameters` |
| `platform/gitea/values.yaml` | Add `domain` and `project_id` defaults for configs chart |
| `platform/gitea/runner-values.yaml` | Replace hardcoded domain with empty (overridden by ArgoCD param) |
| `platform/gitea/templates/certificate.yaml` | Use `{{ .Values.domain }}` |
| `platform/gitea/templates/http-route.yaml` | Use `{{ .Values.domain }}` |
| `platform/gitea/templates/serviceaccount.yaml` | Use `{{ .Values.project_id }}` |
| `platform/bootstrap/templates/app-gitea.yaml` | Switch gitea-configs to `helm:` mode; add domain/project_id params to runner app |
| `platform/external-secrets/templates/grafana-external-secret.yaml` | New: syncs grafana-admin-password from GCP Secret Manager |
| `platform/monitoring/values.yaml` | Reference K8s secret instead of plaintext password |

---

### Task 1: Remove orphaned Backstage secret from Terraform

The Backstage application was removed in commit `81b8104` but four resources remain in `terraform/modules/secrets/main.tf`: a `random_password`, a `google_secret_manager_secret`, a `google_secret_manager_secret_version`, and a `google_secret_manager_secret_iam_member`. These create a real GCP secret and cost money.

**Files:**
- Modify: `terraform/modules/secrets/main.tf`

- [ ] **Step 1: Remove the four backstage resources**

Open `terraform/modules/secrets/main.tf`. Delete the following blocks entirely:

```
resource "random_password" "backstage_db_password" { ... }
resource "google_secret_manager_secret" "backstage_db_password" { ... }
resource "google_secret_manager_secret_version" "backstage_db_password_v1" { ... }
resource "google_secret_manager_secret_iam_member" "eso_backstage_reader" { ... }
```

- [ ] **Step 2: Validate**

```bash
cd terraform
terraform validate
```

Expected output: `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
cd ..
git add terraform/modules/secrets/main.tf
git commit -m "terraform: remove orphaned backstage secret resources"
```

---

### Task 2: Delete unused observability Terraform module

`terraform/modules/observability/` has a `helm_release` for `kube-prometheus-stack` but is never called from `main.tf`. Monitoring is managed via ArgoCD.

**Files:**
- Delete: `terraform/modules/observability/` (entire directory)

- [ ] **Step 1: Delete the directory**

```bash
rm -rf terraform/modules/observability
```

- [ ] **Step 2: Validate Terraform is still valid**

```bash
cd terraform
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
cd ..
git add -A terraform/modules/observability
git commit -m "terraform: remove unused observability module"
```

---

### Task 3: Tighten Terraform version constraint and add variable descriptions

`required_version = ">= 1.0.0"` accepts Terraform 1.0 through any future version including 2.x, which may have breaking changes. Also, all variables across root and modules lack `description` fields.

**Files:**
- Modify: `terraform/providers.tf`
- Modify: `terraform/variables.tf`
- Modify: `terraform/modules/gke/variables.tf`
- Modify: `terraform/modules/iam/variables.tf`
- Modify: `terraform/modules/network/variables.tf`
- Modify: `terraform/modules/secrets/variables.tf`
- Modify: `terraform/modules/artifact_registry/variables.tf`
- Modify: `terraform/modules/argocd/variables.tf`

- [ ] **Step 1: Tighten version constraint in providers.tf**

In `terraform/providers.tf`, change:
```hcl
required_version = ">= 1.0.0"
```
to:
```hcl
required_version = ">= 1.5.0, < 2.0.0"
```

- [ ] **Step 2: Add descriptions to terraform/variables.tf**

Replace the entire contents of `terraform/variables.tf` with:

```hcl
variable "project_id" {
  description = "GCP project ID where all resources are deployed"
  type        = string
}

variable "region" {
  description = "GCP region for all regional resources"
  type        = string
  default     = "europe-west3"
}

variable "env_name" {
  description = "Environment name, used as prefix for VPC and subnet names"
  type        = string
  default     = "prod"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "txt2md-cluster"
}

variable "service_account_email" {
  description = "Email of the pre-existing GCP service account assigned to GKE nodes"
  type        = string
}

variable "repo_url" {
  description = "GitHub repository URL used as the ArgoCD source for the root app"
  type        = string
  default     = "https://github.com/joreichhardt/gke-with-toolset.git"
}

variable "gemini_api_key" {
  description = "Google Gemini API key, stored in GCP Secret Manager"
  type        = string
  sensitive   = true
}

variable "gitea_runner_token" {
  description = "Gitea Actions runner registration token, stored in GCP Secret Manager"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub personal access token for Gitea repository mirroring"
  type        = string
  sensitive   = true
}

variable "github_client_id" {
  description = "GitHub OAuth app client ID for Gitea SSO"
  type        = string
  sensitive   = true
}

variable "github_client_secret" {
  description = "GitHub OAuth app client secret for Gitea SSO"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Root domain for all platform services (e.g. example.com)"
  type        = string
  default     = "hannesalbeiro.com"
}

variable "acme_email" {
  description = "Email address for Let's Encrypt ACME certificate registration"
  type        = string
  default     = "johannes.reichhardt@gmail.com"
}
```

- [ ] **Step 3: Add descriptions to terraform/modules/gke/variables.tf**

Replace contents of `terraform/modules/gke/variables.tf` with:

```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the cluster"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "network_id" {
  description = "Self-link of the VPC network"
  type        = string
}

variable "subnet_id" {
  description = "Self-link of the GKE subnetwork"
  type        = string
}

variable "node_count" {
  description = "Number of nodes per zone in the node pool"
  type        = number
  default     = 1
}

variable "machine_type" {
  description = "GCE machine type for cluster nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "service_account_email" {
  description = "Email of the GCP service account assigned to cluster nodes"
  type        = string
}
```

- [ ] **Step 4: Add descriptions to terraform/modules/iam/variables.tf**

Replace contents with:

```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region (unused by IAM resources, kept for consistency)"
  type        = string
}
```

- [ ] **Step 5: Add descriptions to terraform/modules/network/variables.tf**

Replace contents with:

```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the subnetwork"
  type        = string
}

variable "env_name" {
  description = "Environment name used as prefix for VPC and subnet resource names"
  type        = string
}
```

- [ ] **Step 6: Add descriptions to terraform/modules/secrets/variables.tf**

Replace contents with:

```hcl
variable "project_id" {
  description = "GCP project ID where secrets are stored"
  type        = string
}

variable "gemini_api_key" {
  description = "Google Gemini API key"
  type        = string
  sensitive   = true
}

variable "gitea_runner_token" {
  description = "Gitea Actions runner registration token"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "github_client_id" {
  description = "GitHub OAuth app client ID"
  type        = string
  sensitive   = true
}

variable "github_client_secret" {
  description = "GitHub OAuth app client secret"
  type        = string
  sensitive   = true
}

variable "eso_gsa_email" {
  description = "Email of the External Secrets Operator GSA, granted secretAccessor on all secrets"
  type        = string
}
```

- [ ] **Step 7: Add descriptions to terraform/modules/artifact_registry/variables.tf**

Replace contents with:

```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the Artifact Registry repository"
  type        = string
}
```

- [ ] **Step 8: Add descriptions to terraform/modules/argocd/variables.tf**

Replace contents with:

```hcl
variable "repo_url" {
  description = "GitHub repository URL used as the ArgoCD bootstrap source"
  type        = string
}

variable "domain_name" {
  description = "Root domain for all platform services"
  type        = string
}

variable "acme_email" {
  description = "Email for Let's Encrypt ACME registration"
  type        = string
}

variable "project_id" {
  description = "GCP project ID, passed through to the root ArgoCD Application"
  type        = string
}
```

- [ ] **Step 9: Validate**

```bash
cd terraform
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 10: Commit**

```bash
cd ..
git add terraform/providers.tf terraform/variables.tf \
  terraform/modules/gke/variables.tf \
  terraform/modules/iam/variables.tf \
  terraform/modules/network/variables.tf \
  terraform/modules/secrets/variables.tf \
  terraform/modules/artifact_registry/variables.tf \
  terraform/modules/argocd/variables.tf
git commit -m "terraform: tighten version constraint and add variable descriptions"
```

---

### Task 4: Fix external-dns values.yaml

`platform/external-dns/values.yaml` contains `{{ .Values.project_id | quote }}` and `{{ .Values.domain | quote }}` — Helm template syntax that is never rendered because ArgoCD uses this as a raw values file for the upstream external-dns chart. The actual domain and project overrides are already applied via `helm.parameters` in the ArgoCD Application definition.

**Files:**
- Modify: `platform/external-dns/values.yaml`

- [ ] **Step 1: Remove template syntax from values.yaml**

Replace the entire contents of `platform/external-dns/values.yaml` with:

```yaml
provider: google
google:
  project: ""  # overridden by ArgoCD helm.parameters (google.project)
domainFilters: []  # overridden by ArgoCD helm.parameters (domainFilters[0])
sources:
  - service
  - ingress
  - gateway-httproute
policy: sync
registry: txt
txtPrefix: "k8s-"
txtOwnerId: "txt2md-cluster-v2"
serviceAccount:
  create: true
  name: "external-dns"
  annotations:
    iam.gke.io/gcp-service-account: ""  # overridden by ArgoCD helm.parameters
```

- [ ] **Step 2: Commit**

```bash
git add platform/external-dns/values.yaml
git commit -m "platform: fix external-dns values.yaml broken template syntax"
```

---

### Task 5: Fix cert-manager values.yaml and ArgoCD Application

`platform/cert-manager/values.yaml` hardcodes the service account annotation with the project ID. The fix: remove it from the static values file and inject it as a `helm.parameters` override in the ArgoCD Application, where `project_id` is already available as a bootstrap value.

**Files:**
- Modify: `platform/cert-manager/values.yaml`
- Modify: `platform/bootstrap/templates/app-infrastructure.yaml`

- [ ] **Step 1: Remove hardcoded SA annotation from cert-manager/values.yaml**

Replace the entire contents of `platform/cert-manager/values.yaml` with:

```yaml
installCRDs: true
serviceAccount:
  create: true
  name: "cert-manager"
prometheus:
  enabled: true
  servicemonitor:
    enabled: true
```

- [ ] **Step 2: Add SA annotation as parameter in the ArgoCD Application**

In `platform/bootstrap/templates/app-infrastructure.yaml`, find the `cert-manager` Application source block:

```yaml
  sources:
  - chart: cert-manager
    repoURL: https://charts.jetstack.io
    targetRevision: v1.13.1
    helm:
      valueFiles:
      - $values/platform/cert-manager/values.yaml
```

Change it to:

```yaml
  sources:
  - chart: cert-manager
    repoURL: https://charts.jetstack.io
    targetRevision: v1.13.1
    helm:
      valueFiles:
      - $values/platform/cert-manager/values.yaml
      parameters:
      - name: serviceAccount.annotations.iam\.gke\.io/gcp-service-account
        value: "cert-manager-gsa@{{ .Values.project_id }}.iam.gserviceaccount.com"
```

- [ ] **Step 3: Lint the bootstrap chart**

```bash
helm lint platform/bootstrap --set domain=example.com --set email=test@example.com --set project_id=my-project
```

Expected: `1 chart(s) linted, 0 chart(s) failed`

- [ ] **Step 4: Commit**

```bash
git add platform/cert-manager/values.yaml platform/bootstrap/templates/app-infrastructure.yaml
git commit -m "platform: parameterize cert-manager service account annotation"
```

---

### Task 6: Convert gitea-configs to Helm and parameterize templates

Currently `platform/gitea/` has a `Chart.yaml` but the `gitea-configs` ArgoCD Application uses `directory.recurse: true`, so templates are rendered as raw manifests with hardcoded domain and project ID. Fix: switch to Helm mode and use `{{ .Values.domain }}` / `{{ .Values.project_id }}`.

Also, the `gitea-act-runner` app uses `runner-values.yaml` as a raw values file with a hardcoded `giteaRootURL`. This needs to be overridden via `parameters`.

**Files:**
- Modify: `platform/gitea/values.yaml` (add defaults for domain/project_id)
- Modify: `platform/gitea/runner-values.yaml` (remove hardcoded URL)
- Modify: `platform/gitea/templates/certificate.yaml`
- Modify: `platform/gitea/templates/http-route.yaml`
- Modify: `platform/gitea/templates/serviceaccount.yaml`
- Modify: `platform/bootstrap/templates/app-gitea.yaml`

- [ ] **Step 1: Add domain and project_id defaults to platform/gitea/values.yaml**

Append to the top of `platform/gitea/values.yaml` (before existing content):

```yaml
# gitea-configs chart defaults — overridden by ArgoCD parameters
domain: ""
project_id: ""

```

The full file should look like:

```yaml
# gitea-configs chart defaults — overridden by ArgoCD parameters
domain: ""
project_id: ""

# Gitea application chart values (used via $values reference in gitea ArgoCD app)
config:
  APP_NAME: "Gitea: Git with a cup of tea"
  database:
    DB_TYPE: sqlite3
  actions:
    ENABLED: true
  server:
    DOMAIN: "gitea.hannesalbeiro.com"
    ROOT_URL: "https://gitea.hannesalbeiro.com/"
service:
  http:
    type: ClusterIP
    port: 3000

postgresql:
  enabled: false
redis-cluster:
  enabled: false
postgresql-ha:
  enabled: false
memcached:
  enabled: false
```

- [ ] **Step 2: Update runner-values.yaml to remove hardcoded URL**

Replace the `giteaRootURL` line in `platform/gitea/runner-values.yaml`:

```yaml
giteaRootURL: ""  # overridden by ArgoCD helm.parameters
```

Full file after change:

```yaml
# Config for Gitea Actions (Chart: gitea/actions v0.0.4)
enabled: true

giteaRootURL: ""  # overridden by ArgoCD helm.parameters
existingSecret: "gitea-runner-secret"
existingSecretKey: "token"

statefulset:
  replicas: 1
  serviceAccountName: "gitea-act-runner"
  actRunner:
    config: |
      log:
        level: info
      cache:
        enabled: false
      container:
        require_docker: true
        docker_timeout: 300s
        privileged: true
  dind:
    # GKE Autopilot needs some help with dind
    {}
```

- [ ] **Step 3: Parameterize platform/gitea/templates/certificate.yaml**

Replace the entire file:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: gitea-cert
  namespace: gitea-ci
spec:
  secretName: gitea-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: "gitea.{{ .Values.domain }}"
  dnsNames:
  - "gitea.{{ .Values.domain }}"
```

- [ ] **Step 4: Parameterize platform/gitea/templates/http-route.yaml**

Replace the entire file:

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: gitea-route
  namespace: gitea-ci
spec:
  parentRefs:
  - name: external-http
    namespace: kube-system
    sectionName: https
  hostnames:
  - "gitea.{{ .Values.domain }}"
  rules:
  - backendRefs:
    - name: gitea-http
      port: 3000
```

- [ ] **Step 5: Parameterize platform/gitea/templates/serviceaccount.yaml**

Replace the entire file:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitea-act-runner
  namespace: gitea-ci
  annotations:
    iam.gke.io/gcp-service-account: "gitea-runner-gsa@{{ .Values.project_id }}.iam.gserviceaccount.com"
```

- [ ] **Step 6: Switch gitea-configs to Helm mode and add runner giteaRootURL parameter**

In `platform/bootstrap/templates/app-gitea.yaml`, make two changes:

**Change 1** — `gitea-configs` Application: replace `directory.recurse: true` with `helm.parameters`:

Find:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gitea-configs
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/joreichhardt/gke-with-toolset.git
    targetRevision: HEAD
    path: platform/gitea
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: gitea-ci
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Replace with:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gitea-configs
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/joreichhardt/gke-with-toolset.git
    targetRevision: HEAD
    path: platform/gitea
    helm:
      parameters:
      - name: domain
        value: {{ .Values.domain | quote }}
      - name: project_id
        value: {{ .Values.project_id | quote }}
  destination:
    server: https://kubernetes.default.svc
    namespace: gitea-ci
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Change 2** — `gitea-act-runner` Application: add `giteaRootURL` parameter to the helm source block. Find the actions chart source:

```yaml
  sources:
  - chart: actions
    repoURL: https://dl.gitea.com/charts/
    targetRevision: 0.0.4
    helm:
      valueFiles:
      - $values/platform/gitea/runner-values.yaml
```

Replace with:
```yaml
  sources:
  - chart: actions
    repoURL: https://dl.gitea.com/charts/
    targetRevision: 0.0.4
    helm:
      valueFiles:
      - $values/platform/gitea/runner-values.yaml
      parameters:
      - name: giteaRootURL
        value: "https://gitea.{{ .Values.domain }}/"
```

- [ ] **Step 7: Lint the bootstrap chart**

```bash
helm lint platform/bootstrap --set domain=example.com --set email=test@example.com --set project_id=my-project
```

Expected: `1 chart(s) linted, 0 chart(s) failed`

- [ ] **Step 8: Lint the gitea-configs chart in isolation**

```bash
helm lint platform/gitea --set domain=example.com --set project_id=my-project
```

Expected: `1 chart(s) linted, 0 chart(s) failed`

- [ ] **Step 9: Verify template output looks correct**

```bash
helm template platform/gitea --set domain=example.com --set project_id=my-project
```

Verify output contains:
- `commonName: "gitea.example.com"` in the Certificate
- `- "gitea.example.com"` in the HTTPRoute hostnames
- `iam.gke.io/gcp-service-account: "gitea-runner-gsa@my-project.iam.gserviceaccount.com"` in the ServiceAccount

- [ ] **Step 10: Commit**

```bash
git add platform/gitea/ platform/bootstrap/templates/app-gitea.yaml
git commit -m "platform: convert gitea-configs to Helm and parameterize templates"
```

---

### Task 7: Add Grafana admin password secret to Terraform

The Grafana admin password is currently hardcoded as `"prom-operator"` in `platform/monitoring/values.yaml`. This task adds it as a managed secret in GCP Secret Manager (random-generated, like the Flask secret key).

**Files:**
- Modify: `terraform/modules/secrets/main.tf`

- [ ] **Step 1: Add grafana-admin-password resources to secrets/main.tf**

Append the following to the end of `terraform/modules/secrets/main.tf`:

```hcl
# Grafana Admin Password managed in Secret Manager
resource "random_password" "grafana_admin_password" {
  length  = 24
  special = false
}

resource "google_secret_manager_secret" "grafana_admin_password" {
  secret_id = "grafana-admin-password"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "grafana_admin_password_v1" {
  secret      = google_secret_manager_secret.grafana_admin_password.id
  secret_data = random_password.grafana_admin_password.result
}

resource "google_secret_manager_secret_iam_member" "eso_grafana_reader" {
  secret_id = google_secret_manager_secret.grafana_admin_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.eso_gsa_email}"
}
```

- [ ] **Step 2: Validate**

```bash
cd terraform
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
cd ..
git add terraform/modules/secrets/main.tf
git commit -m "terraform: add grafana-admin-password to GCP Secret Manager"
```

---

### Task 8: Add Grafana ExternalSecret and update monitoring values

Wire the GCP secret from Task 7 into the cluster via ESO, and configure Grafana to read it from a K8s Secret instead of the hardcoded plaintext value.

**Files:**
- Create: `platform/external-secrets/templates/grafana-external-secret.yaml`
- Modify: `platform/monitoring/values.yaml`

- [ ] **Step 1: Create the Grafana ExternalSecret**

Create `platform/external-secrets/templates/grafana-external-secret.yaml`:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: grafana-admin-password
  namespace: monitoring
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: gcp-store
  target:
    name: grafana-admin-secret
    creationPolicy: Owner
  data:
  - secretKey: admin-password
    remoteRef:
      key: grafana-admin-password
```

- [ ] **Step 2: Update monitoring values.yaml to use the K8s secret**

In `platform/monitoring/values.yaml`, in the `grafana:` section, replace:

```yaml
grafana:
  adminPassword: "prom-operator" # Change this!
```

with:

```yaml
grafana:
  admin:
    existingSecret: "grafana-admin-secret"
    passwordKey: "admin-password"
```

- [ ] **Step 3: Lint the external-secrets chart**

```bash
helm lint platform/external-secrets --set project_id=my-project
```

Expected: `1 chart(s) linted, 0 chart(s) failed`

- [ ] **Step 4: Commit**

```bash
git add platform/external-secrets/templates/grafana-external-secret.yaml \
        platform/monitoring/values.yaml
git commit -m "platform: manage grafana admin password via GCP Secret Manager and ESO"
```

---

## Self-Review

**Spec coverage:**
- A1 (backstage secret) → Task 1 ✓
- A2 (observability module) → Task 2 ✓
- A3 (external-dns values) → Task 4 ✓
- A4 (cert-manager values) → Task 5 ✓
- B1 (gitea parameterization) → Task 6 ✓
- C1 (grafana password) → Tasks 7 + 8 ✓
- D1 (variable descriptions) → Task 3 ✓
- D2 (version constraint) → Task 3 ✓

**Dependencies:**
- Task 8 references the GCP secret created in Task 7 — must run in order.
- All other tasks are independent.
