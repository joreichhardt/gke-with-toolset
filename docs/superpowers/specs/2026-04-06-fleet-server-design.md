# Fleet Server + Elastic Agent via ECK — Design Spec

**Date:** 2026-04-06  
**Status:** Approved

---

## Context

The cluster already runs:
- ECK Operator (ArgoCD wave 0)
- Elasticsearch 8.11.0 + Kibana 8.11.0 (ECK, namespace `logging`, wave 1)
- Fluent Bit DaemonSet for log collection (wave 2)

Fluent Bit continues to handle log collection. Fleet Server + Elastic Agent are added exclusively for metrics.

---

## Goal

Collect Kubernetes metrics (nodes, pods, deployments) and host-level system metrics (CPU, disk, network) from all GKE nodes and external hosts, managed centrally via Kibana Fleet UI.

---

## Architecture

```
Kibana Fleet UI
      │
      ▼
Fleet Server (ECK Agent, Deployment, 1 Replica)
      │  ← LoadBalancer Service Port 8220 (externally accessible)
      ├── Elastic Agent DaemonSet (ECK, all GKE Nodes)
      │       • kubernetes Integration (K8s metrics)
      │       • system Integration (host CPU/Disk/Network)
      └── External Hosts (manually enrolled via external IP:8220)
            • elastic-agent package installed
            • system Integration
```

---

## Implementation

### New files in `platform/logging/`

All files are auto-synced by the existing `logging-configs` ArgoCD Application.

| File | Contents |
|------|----------|
| `fleet-server.yaml` | ECK `Agent` CR (Fleet Server, Deployment) + ServiceAccount + ClusterRole + ClusterRoleBinding |
| `elastic-agent.yaml` | ECK `Agent` CR (DaemonSet) + ServiceAccount + ClusterRole + ClusterRoleBinding |
| `fleet-server-service.yaml` | LoadBalancer Service on port 8220 with external-dns annotation |

### Sync ordering

Sync-wave annotations within resources ensure Fleet Server is ready before Elastic Agent enrolls:
- Fleet Server resources: wave 2
- Elastic Agent resources: wave 3

(The parent `logging-configs` ArgoCD app is already wave 1.)

### ServiceAccounts

Both Fleet Server and Elastic Agent need dedicated ServiceAccounts with ClusterRoles to read Kubernetes API resources (nodes, pods, namespaces, events, etc.).

### External host enrollment

After Fleet Server is running:
1. Copy enrollment token from Kibana Fleet UI
2. On each external host:
   ```bash
   elastic-agent install --url=https://<fleet-server-external-ip>:8220 \
     --enrollment-token=<token> \
     --insecure
   ```

---

## Post-Deployment Steps (Kibana Fleet UI)

1. Verify Fleet Server shows as healthy in Fleet UI
2. Add `kubernetes` integration to the Agent policy (for GKE node agents)
3. Add `system` integration to the Agent policy (for all agents)
4. For external hosts: create a separate policy if different integrations are needed

---

## What is NOT changing

- Fluent Bit remains the log collector — no change to `fluent-bit-values.yaml`
- Elasticsearch and Kibana resources are unchanged
- No new ArgoCD Applications — existing `logging-configs` app picks up new files automatically

---

## Version

All ECK resources use version `8.11.0` to match the existing Elasticsearch and Kibana deployments.
