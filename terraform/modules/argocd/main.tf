locals {
  cert_secret_name = "wildcard-${replace(var.domain_name, ".", "-")}-cert"
  get_credentials  = "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.project_id}"
}

# Restore TLS cert from GCS before ArgoCD applies the Certificate resource.
# If no backup exists, this is a no-op and cert-manager will request a new cert.
resource "null_resource" "restore_tls_cert" {
  depends_on = [helm_release.argocd]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      ${local.get_credentials}
      if gsutil -q stat gs://${var.cert_bucket}/tls-certs/wildcard-cert.json 2>/dev/null; then
        echo "Restoring TLS certificate from GCS..."
        gsutil cat gs://${var.cert_bucket}/tls-certs/wildcard-cert.json | kubectl apply -f -
        echo "Certificate restored."
      else
        echo "No certificate backup found in gs://${var.cert_bucket}, skipping restore."
      fi
    EOT
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.46.7"

  set {
    name  = "server.extraArgs"
    value = "{--insecure}"
  }
}

# Backup TLS cert to GCS on destroy, before the cluster is torn down.
# Stored values in triggers so the destroy provisioner can reference them via self.triggers.
resource "null_resource" "backup_tls_cert" {
  depends_on = [kubectl_manifest.root_app]

  triggers = {
    bucket       = var.cert_bucket
    secret_name  = local.cert_secret_name
    cluster_name = var.cluster_name
    region       = var.region
    project_id   = var.project_id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      gcloud container clusters get-credentials ${self.triggers.cluster_name} \
        --region ${self.triggers.region} --project ${self.triggers.project_id}
      kubectl get secret ${self.triggers.secret_name} -n kube-system -o json | \
        python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in ['resourceVersion', 'uid', 'creationTimestamp', 'managedFields', 'annotations']:
    d['metadata'].pop(k, None)
print(json.dumps(d))
" | gsutil cp - gs://${self.triggers.bucket}/tls-certs/wildcard-cert.json \
        && echo "Certificate backed up to gs://${self.triggers.bucket}/tls-certs/wildcard-cert.json" \
        || echo "Warning: certificate backup failed (secret may not exist yet)"
    EOT
  }
}

resource "kubectl_manifest" "root_app" {
  depends_on = [helm_release.argocd, null_resource.restore_tls_cert]
  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${var.repo_url}
    targetRevision: HEAD
    path: platform/bootstrap
    helm:
      parameters:
      - name: domain
        value: "${var.domain_name}"
      - name: email
        value: "${var.acme_email}"
      - name: project_id
        value: "${var.project_id}"
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML
}
