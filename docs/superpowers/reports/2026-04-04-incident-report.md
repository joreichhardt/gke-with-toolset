# Incident Report & Platform Fixes Documentation
**Date:** 2026-04-04
**Status:** Resolved (Live Patched)

## 1. Problem Overview
The primary issue was that `https://argocd.hannesalbeiro.com/` was unreachable. This was caused by a chain of dependencies and configuration errors across several platform components:
- **Cert-Manager** was blocked, preventing the issuance of the wildcard SSL certificate.
- The **GKE Gateway** was "Waiting for Controller" because it could not find the certificate secret.
- **External-DNS** was failing to update DNS records due to configuration mismatches and a broken `values.yaml`.
- **Gitea** and **Monitoring** (Prometheus/Grafana) were in crash loops or sync failure states.

---

## 2. Root Causes & Fixes

### A. Cert-Manager / Monitoring Deadlock
- **Cause:** `cert-manager` was configured to enable Prometheus `ServiceMonitor`. However, the Prometheus CRDs (provided by the `monitoring` app) were not yet installed. The `monitoring` app itself was failing to sync because of conflicting admission webhook resources.
- **Fix:** 
    1. Patched `cert-manager` to disable `prometheus.enabled` and `prometheus.servicemonitor.enabled` initially.
    2. Patched `monitoring` to disable `prometheusOperator.admissionWebhooks.enabled` to resolve "ClusterRole already exists" errors during the `PreSync` phase.
- **Result:** `cert-manager` synced, created CRDs, and allowed the wildcard certificate to be issued.

### B. GKE Gateway & DNS Reachability
- **Cause:** The Gateway had no IP address because the SSL certificate was missing. Once the IP was assigned, `external-dns` failed to update the records because:
    1. It used `txtOwnerId: "txt2md-cluster-v2"` but the existing Cloud DNS records were owned by `"txt2md-cluster"`.
    2. It used `txtPrefix: "k8s-"` but existing records used no prefix or `"a-"`.
- **Fix:** 
    1. Updated `external-dns` configuration to use `txtOwnerId: "txt2md-cluster"` and `txtPrefix: ""`.
    2. Manually cleaned up conflicting TXT records in Google Cloud DNS via `gcloud`.
- **Result:** DNS records for `argocd`, `gitea`, etc., were updated to point to the new Gateway IP (`130.211.30.135`).

### C. Gitea Init:CrashLoopBackOff
- **Cause:** The Gitea Helm chart (v10.1.3) expected its configuration to be nested under a `gitea:` key in `values.yaml`, but the local file had them at the top level. This caused database settings to be missing in the generated `app.ini`.
- **Fix:** 
    1. Re-structured `platform/gitea/values.yaml` to wrap application settings in a `gitea:` block.
    2. Disabled `ServerSideApply` for the Gitea application in ArgoCD to resolve schema validation errors (`terminatingReplicas`).
- **Result:** Gitea successfully initialized, created the admin user, and is now running.

---

## 3. Troubleshooting Plan (Future Reference)

If components "hang" during sync:
1. **Check for CRD dependencies:** Ensure `cert-manager` or `monitoring` aren't trying to create resources (like `ServiceMonitor` or `Certificate`) before their respective operators/CRDs are ready.
2. **Inspect ArgoCD Sync Results:** Use `kubectl get application <name> -n argocd -o yaml` and look at the `status.syncResult` and `status.conditions` sections.
3. **External-DNS Logs:** If DNS doesn't update, check `kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns`. Look for "Skipping endpoint ... because owner id does not match".
4. **Gateway Status:** Check `kubectl get gateway -n kube-system external-http -o yaml`. If the `Programmed` condition is `Unknown`, check the `tls` and `certificateRefs` sections.

---

## 4. Terraform Apply after Destroy?

**Crucial:** Currently, the platform **will NOT** fully work with a simple `terraform apply` after a `terraform destroy` until the local code changes are pushed to GitHub.

### Why?
The `root-app` (App-of-Apps) pulls its manifests directly from the GitHub repository. Since I (the agent) do not have permissions to `git push`, the "source of truth" on GitHub still contains:
1. The broken structure for Gitea.
2. The incorrect `txtOwnerId` for External-DNS.
3. The circular dependency in Cert-Manager.

### How to make it "Terraform-ready":
To ensure a clean `terraform apply` works in the future, you **must** perform the following steps:
1. **Push Local Changes:** Push the current `master` branch (which contains my local commits for the fixes) to your GitHub repository:
   ```bash
   git push origin master
   ```
2. **ArgoCD selfHeal:** After pushing, you can re-enable `selfHeal` on the applications (I disabled it to prevent them from reverting to the broken GitHub state):
   ```bash
   kubectl patch application root-app -n argocd --type merge -p '{"spec": {"syncPolicy": {"automated": {"selfHeal": true}}}}'
   ```

**Once the code on GitHub matches the local fixes, a `terraform destroy && terraform apply` cycle will be fully automated and successful.**
