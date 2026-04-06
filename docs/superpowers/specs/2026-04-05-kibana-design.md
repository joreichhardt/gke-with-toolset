# ELK Stack Integration (ECK self-hosted) — Design Spec

**Date:** 2026-04-05
**Status:** Approved

## Goal

Add centralized log aggregation and visualization to the GKE platform using the Elastic Stack (ECK Operator + Elasticsearch + Kibana + Fluent Bit), deployed via ArgoCD following the existing GitOps pattern.

## Approach

ECK Operator (Elastic Cloud on Kubernetes) manages the Elasticsearch and Kibana lifecycle via Kubernetes Custom Resources. Fluent Bit runs as a DaemonSet to collect logs from all pods cluster-wide.

Chosen over:
- Elastic Helm Charts without ECK (less portfolio value, worse lifecycle management)
- Elastic Cloud on GCP managed service (less technical depth, external data)
- OpenSearch (Elastic brand more relevant in job market)

## Components

| Component | Deployment | Namespace |
|---|---|---|
| ECK Operator | Helm Chart via ArgoCD | `elastic-system` |
| Elasticsearch | ECK `Elasticsearch` CRD | `logging` |
| Kibana | ECK `Kibana` CRD | `logging` |
| Fluent Bit | Helm Chart (DaemonSet) | `logging` |

## Repository Structure

```
platform/
  logging/
    elasticsearch.yaml      # ECK Elasticsearch CRD
    kibana.yaml             # ECK Kibana CRD
    fluent-bit-values.yaml  # Fluent Bit Helm values
platform/bootstrap/templates/
  app-logging.yaml          # 3 ArgoCD Applications
```

## ArgoCD Sync Waves

ECK CRDs must exist before Custom Resources are applied.

- **Wave 0:** ECK Operator (installs CRDs)
- **Wave 1:** Elasticsearch
- **Wave 2:** Kibana + Fluent Bit

## Data Flow

```
Pod logs (stdout/stderr)
    ↓
Fluent Bit (reads /var/log/containers/*.log from each node)
    ↓  [TLS + Basic Auth via elastic-user Secret]
Elasticsearch (logging namespace)
    ↓
Kibana (Index Pattern: fluent-bit-*)
```

Fluent Bit enriches logs with Kubernetes metadata (namespace, pod name, container name, labels) for filtering in Kibana.

## Resource Sizing

**Elasticsearch (1 node):**
- RAM: requests 2Gi / limits 4Gi
- CPU: requests 500m / limits 1000m
- Storage: 30Gi PVC (`standard-rwo`)

**Kibana:**
- RAM: requests 512Mi / limits 1Gi
- CPU: requests 250m / limits 500m
- Storage: none

**Fluent Bit (per node):**
- RAM: requests 50Mi / limits 128Mi
- CPU: requests 50m / limits 200m

## Security

- ECK auto-generates TLS certificates and an `elastic` user Secret (`<name>-es-elastic-user`)
- Fluent Bit references the elastic user Secret as environment variable — no credentials in Git
- Fluent Bit communicates with Elasticsearch cluster-internally via TLS (ECK CA)
- Kibana exposed at `kibana.<domain>` via existing Gateway + cert-manager (Let's Encrypt TLS)
- No new GCP IAM resources required — everything stays cluster-internal

## Access

- Kibana URL: `kibana.<domain>`
- Login: `elastic` user + auto-generated password
- Password retrieval: `kubectl get secret <name>-es-elastic-user -n logging -o jsonpath='{.data.elastic}' | base64 -d`
- Same pattern as existing Grafana/Gitea password retrieval

## Out of Scope

- Multi-node Elasticsearch HA (single node sufficient for portfolio)
- Logstash (Fluent Bit ships directly to Elasticsearch)
- Index Lifecycle Management (ILM) policies
- Elasticsearch Snapshot/Backup
