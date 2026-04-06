# ELK Stack (ECK) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy ECK Operator + Elasticsearch + Kibana + Fluent Bit on GKE via ArgoCD GitOps, exposing Kibana at `kibana.<domain>` with cluster-wide log collection.

**Architecture:** ECK Operator (sync wave 0) manages Elasticsearch and Kibana lifecycle via CRDs. Fluent Bit runs as a DaemonSet (sync wave 2), ships logs from all nodes to Elasticsearch. Kibana is exposed through the existing GKE Gateway with TLS termination.

**Tech Stack:** ECK Operator 2.10.0, Elasticsearch 8.11.0, Kibana 8.11.0, Fluent Bit Helm chart 0.43.0, ArgoCD App-of-Apps pattern, GKE Gateway API.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `platform/bootstrap/templates/app-logging.yaml` | Create | 3 ArgoCD Applications: eck-operator, logging-configs, fluent-bit |
| `platform/logging/elasticsearch.yaml` | Create | ECK Elasticsearch CRD (1 node, 30Gi, standard-rwo) |
| `platform/logging/kibana.yaml` | Create | ECK Kibana CRD, TLS disabled for gateway passthrough |
| `platform/logging/fluent-bit-values.yaml` | Create | Fluent Bit Helm values, cluster-wide log collection |
| `platform/gateway/templates/http-routes.yaml` | Modify | Add Kibana HTTPRoute in `logging` namespace |

---

### Task 1: ECK Operator ArgoCD Application (sync wave 0)

**Files:**
- Create: `platform/bootstrap/templates/app-logging.yaml`

- [ ] **Step 1: Create app-logging.yaml with ECK Operator application**

```yaml
# platform/bootstrap/templates/app-logging.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: eck-operator
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  project: default
  source:
    chart: eck-operator
    repoURL: https://helm.elastic.co
    targetRevision: 2.10.0
  destination:
    server: https://kubernetes.default.svc
    namespace: elastic-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
```

- [ ] **Step 2: Commit**

```bash
git add platform/bootstrap/templates/app-logging.yaml
git commit -m "feat: add ECK operator ArgoCD application (wave 0)"
```

---

### Task 2: Elasticsearch CRD + logging-configs ArgoCD Application

**Files:**
- Create: `platform/logging/elasticsearch.yaml`
- Modify: `platform/bootstrap/templates/app-logging.yaml`

- [ ] **Step 1: Create Elasticsearch CRD**

```yaml
# platform/logging/elasticsearch.yaml
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: elasticsearch
  namespace: logging
spec:
  version: 8.11.0
  nodeSets:
  - name: default
    count: 1
    config:
      node.store.allow_mmap: false
    podTemplate:
      spec:
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 2Gi
              cpu: 500m
            limits:
              memory: 4Gi
              cpu: "1"
          env:
          - name: ES_JAVA_OPTS
            value: "-Xms1g -Xmx1g"
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 30Gi
        storageClassName: standard-rwo
```

Note: `node.store.allow_mmap: false` avoids needing to raise `vm.max_map_count` on GKE nodes.

- [ ] **Step 2: Add logging-configs Application to app-logging.yaml**

Append to `platform/bootstrap/templates/app-logging.yaml`:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: logging-configs
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  project: default
  source:
    repoURL: https://github.com/joreichhardt/gke-with-toolset.git
    targetRevision: HEAD
    path: platform/logging
    directory:
      include: "*.yaml"
      exclude: "fluent-bit-values.yaml"
  destination:
    server: https://kubernetes.default.svc
    namespace: logging
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 30s
        factor: 2
        maxDuration: 5m
```

Note: The retry policy handles the case where ECK CRDs aren't registered yet when logging-configs first syncs.

- [ ] **Step 3: Commit**

```bash
git add platform/logging/elasticsearch.yaml platform/bootstrap/templates/app-logging.yaml
git commit -m "feat: add Elasticsearch CRD and logging-configs ArgoCD application"
```

---

### Task 3: Kibana CRD + HTTPRoute

**Files:**
- Create: `platform/logging/kibana.yaml`
- Modify: `platform/gateway/templates/http-routes.yaml`

- [ ] **Step 1: Create Kibana CRD**

```yaml
# platform/logging/kibana.yaml
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: kibana
  namespace: logging
spec:
  version: 8.11.0
  count: 1
  elasticsearchRef:
    name: elasticsearch
  http:
    tls:
      selfSignedCertificate:
        disabled: true
  podTemplate:
    spec:
      containers:
      - name: kibana
        resources:
          requests:
            memory: 512Mi
            cpu: 250m
          limits:
            memory: 1Gi
            cpu: 500m
```

Note: `selfSignedCertificate.disabled: true` makes Kibana serve plain HTTP on port 5601 so the GKE Gateway can forward traffic without TLS re-encryption.

- [ ] **Step 2: Add Kibana HTTPRoute to gateway**

Append to `platform/gateway/templates/http-routes.yaml`:

```yaml
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: kibana-route
  namespace: logging
spec:
  parentRefs:
  - name: external-http
    namespace: kube-system
    sectionName: https
  hostnames:
  - "kibana.{{ .Values.domain }}"
  rules:
  - backendRefs:
    - name: kibana-kb-http
      port: 5601
```

Note: The Gateway has `allowedRoutes.namespaces.from: All`, so this cross-namespace HTTPRoute works without a ReferenceGrant.

- [ ] **Step 3: Commit**

```bash
git add platform/logging/kibana.yaml platform/gateway/templates/http-routes.yaml
git commit -m "feat: add Kibana CRD and HTTPRoute for kibana.<domain>"
```

---

### Task 4: Fluent Bit values + ArgoCD Application

**Files:**
- Create: `platform/logging/fluent-bit-values.yaml`
- Modify: `platform/bootstrap/templates/app-logging.yaml`

- [ ] **Step 1: Create Fluent Bit Helm values**

```yaml
# platform/logging/fluent-bit-values.yaml
env:
- name: ELASTIC_PASSWORD
  valueFrom:
    secretKeyRef:
      name: elasticsearch-es-elastic-user
      key: elastic

tolerations:
- key: node-role.kubernetes.io/control-plane
  operator: Exists
  effect: NoSchedule

resources:
  requests:
    cpu: 50m
    memory: 50Mi
  limits:
    cpu: 200m
    memory: 128Mi

config:
  service: |
    [SERVICE]
        Flush         1
        Daemon        Off
        Log_Level     warn
        Parsers_File  /fluent-bit/etc/parsers.conf
        HTTP_Server   On
        HTTP_Listen   0.0.0.0
        HTTP_Port     2020

  inputs: |
    [INPUT]
        Name              tail
        Tag               kube.*
        Path              /var/log/containers/*.log
        multiline.parser  cri
        DB                /var/log/flb_kube.db
        Mem_Buf_Limit     50MB
        Skip_Long_Lines   On
        Refresh_Interval  10

  filters: |
    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Kube_Tag_Prefix     kube.var.log.containers.
        Merge_Log           On
        Keep_Log            Off
        K8S-Logging.Parser  On
        K8S-Logging.Exclude On

  outputs: |
    [OUTPUT]
        Name                es
        Match               kube.*
        Host                elasticsearch-es-http.logging.svc.cluster.local
        Port                9200
        HTTP_User           elastic
        HTTP_Passwd         ${ELASTIC_PASSWORD}
        tls                 On
        tls.verify          Off
        Index               fluent-bit
        Logstash_Format     On
        Logstash_Prefix     fluent-bit
        Suppress_Type_Name  On
        Retry_Limit         False
```

Note: `tls.verify Off` skips verification of ECK's self-signed CA (acceptable for intra-cluster traffic). `Logstash_Format On` creates daily indices `fluent-bit-YYYY.MM.DD` for easy filtering in Kibana.

- [ ] **Step 2: Add Fluent Bit Application to app-logging.yaml**

Append to `platform/bootstrap/templates/app-logging.yaml`:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fluent-bit
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  project: default
  sources:
  - chart: fluent-bit
    repoURL: https://fluent.github.io/helm-charts
    targetRevision: 0.43.0
    helm:
      valueFiles:
      - $values/platform/logging/fluent-bit-values.yaml
  - repoURL: https://github.com/joreichhardt/gke-with-toolset.git
    targetRevision: HEAD
    ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: logging
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
```

- [ ] **Step 3: Commit**

```bash
git add platform/logging/fluent-bit-values.yaml platform/bootstrap/templates/app-logging.yaml
git commit -m "feat: add Fluent Bit values and ArgoCD application (wave 2)"
```

---

### Task 5: Verify Deployment

After pushing to `master`, ArgoCD syncs automatically. Verify each component in order.

- [ ] **Step 1: Verify ECK Operator is running**

```bash
kubectl get pods -n elastic-system
```

Expected: `elastic-operator-0` with status `Running`

- [ ] **Step 2: Verify Elasticsearch is healthy**

```bash
kubectl get elasticsearch -n logging
```

Expected: `NAME: elasticsearch  HEALTH: green  NODES: 1  VERSION: 8.11.0  PHASE: Ready`

This can take 2-3 minutes for the first startup.

- [ ] **Step 3: Verify Kibana is healthy**

```bash
kubectl get kibana -n logging
```

Expected: `NAME: kibana  HEALTH: green  NODES: 1  VERSION: 8.11.0`

- [ ] **Step 4: Verify Fluent Bit DaemonSet**

```bash
kubectl get daemonset -n logging
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=20
```

Expected: DaemonSet with `DESIRED` == number of nodes, no connection errors in logs.

- [ ] **Step 5: Verify logs reach Elasticsearch**

```bash
ELASTIC_PASSWORD=$(kubectl get secret elasticsearch-es-elastic-user -n logging -o jsonpath='{.data.elastic}' | base64 -d)
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n logging -- \
  curl -k -u "elastic:${ELASTIC_PASSWORD}" https://elasticsearch-es-http:9200/_cat/indices?v
```

Expected: indices named `fluent-bit-YYYY.MM.DD` with non-zero `docs.count`.

- [ ] **Step 6: Verify Kibana is accessible**

Open `https://kibana.<domain>` in browser. Login with:
```bash
kubectl get secret elasticsearch-es-elastic-user -n logging -o jsonpath='{.data.elastic}' | base64 -d
```
User: `elastic`, Password: output of above command.

Expected: Kibana UI loads. Navigate to **Management → Stack Management → Data Views**, create a Data View with index pattern `fluent-bit-*` and timestamp field `@timestamp`.

- [ ] **Step 7: Verify log data in Kibana**

Navigate to **Discover**, select the `fluent-bit-*` Data View. Filter by `kubernetes.namespace_name: monitoring`.

Expected: Logs from Prometheus/Grafana pods appear with `kubernetes.pod_name`, `kubernetes.namespace_name`, and `log` fields.
