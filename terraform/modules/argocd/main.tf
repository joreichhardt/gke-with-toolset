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

resource "kubectl_manifest" "root_app" {
  depends_on = [helm_release.argocd]
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
