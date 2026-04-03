# Platform Fixes — Design Spec
Date: 2026-04-03

## Scope

Fix dead code, broken template syntax, hardcoded values, and security issues across the GKE platform repo. Alertmanager stays silent (no receiver change).

---

## A: Dead Code / Bugs

### A1 — Remove orphaned Backstage secret from Terraform
`terraform/modules/secrets/main.tf` still creates `backstage-db-password` (random password + GCP Secret + IAM binding) even though Backstage was removed in commit `81b8104`. These resources serve no purpose and cost money.

**Change:** Remove the three `backstage_db_password` resources and the `random_password.backstage_db_password` resource from `modules/secrets/main.tf`. No variable change needed (there never was a `backstage_db_password` variable).

### A2 — Delete unused observability Terraform module
`terraform/modules/observability/` contains a Helm release for `kube-prometheus-stack` but is never called from `main.tf`. Monitoring is deployed via ArgoCD instead. This is dead code.

**Change:** Delete `terraform/modules/observability/` entirely.

### A3 — Fix external-dns values.yaml
`platform/external-dns/values.yaml` contains Helm template syntax (`{{ .Values.project_id | quote }}`, `{{ .Values.domain | quote }}`). ArgoCD uses this file as a raw values file for the upstream external-dns chart — the syntax is never rendered and would cause an error. The domain and project_id are already correctly set via `helm.parameters` in the ArgoCD Application definition.

**Change:** Replace template expressions with empty/placeholder strings that are overridden by the ArgoCD parameters:
- `google.project: ""` (overridden by parameter)
- `domainFilters: []` (overridden by parameter)

### A4 — Fix cert-manager values.yaml
`platform/cert-manager/values.yaml` has the GCP service account email hardcoded as `cert-manager-gsa@project-84ddd43d-e408-4cb9-8cb.iam.gserviceaccount.com`. The ArgoCD `cert-manager-configs` app already passes `project_id` as a parameter. However, `values.yaml` is used for the upstream cert-manager *chart* (not the configs chart), so the annotation must be set as an ArgoCD `parameter` override on the cert-manager application rather than in the static values file.

**Change:** Remove the hardcoded service account annotation from `cert-manager/values.yaml` and add it as a `helm.parameters` entry in the ArgoCD Application definition in `platform/bootstrap/templates/app-infrastructure.yaml`.

---

## B: Gitea Templates — Parameterization

### B1 — Convert gitea-configs to proper Helm
Currently `platform/gitea/` has a `Chart.yaml` but the ArgoCD app uses `directory.recurse: true`, treating files as raw manifests. The templates have hardcoded `gitea.hannesalbeiro.com` and the project-specific GCP service account email.

**Change:**
1. Update the `gitea-configs` ArgoCD Application in `app-gitea.yaml` to use `helm.parameters` (passing `domain` and `project_id` from `.Values`) instead of `directory.recurse`.
2. Add a `values.yaml` to `platform/gitea/` with empty defaults for `domain` and `project_id`.
3. Update `templates/certificate.yaml`, `templates/http-route.yaml`, `templates/service.yaml`, and `templates/serviceaccount.yaml` to use `{{ .Values.domain }}` and `{{ .Values.project_id }}`.
4. Update `values.yaml` (gitea chart config) and `runner-values.yaml` to use `{{ .Values.domain }}` where applicable.

---

## C: Security

### C1 — Grafana admin password as ExternalSecret
`platform/monitoring/values.yaml` has `adminPassword: "prom-operator"` in plaintext. This should be managed via GCP Secret Manager + ESO, consistent with other secrets.

**Change:**
1. Add a `grafana-admin-password` secret to `terraform/modules/secrets/main.tf` (random generated, like `flask_secret`).
2. Add `platform/external-secrets/templates/grafana-external-secret.yaml` to sync it as a K8s Secret.
3. Update `platform/monitoring/values.yaml` to reference the K8s secret via `grafana.admin.existingSecret`.

---

## D: Terraform Quality

### D1 — Add variable descriptions
All variables in `terraform/variables.tf` and module `variables.tf` files lack `description` fields. Add concise descriptions.

### D2 — Tighten Terraform version constraint
`required_version = ">= 1.0.0"` is too broad. Change to `>= 1.5.0, < 2.0.0`.

---

## Out of Scope

- Alertmanager receiver (stays as `null` — silent)
- Chart version upgrades (potentially breaking, separate effort)
- GKE deletion_protection (intentional choice)
- ArgoCD `--insecure` flag (intentional — TLS terminated at Gateway)
