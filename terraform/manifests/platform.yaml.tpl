apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: hannes@${domain_name}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - dns01:
        cloudDNS:
          project: ${project_id}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: main-cert
  namespace: default
spec:
  secretName: main-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: "*.${domain_name}"
  dnsNames:
  - "*.${domain_name}"
  - "${domain_name}"
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: main-gateway
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  gatewayClassName: gke-l7-global-external-managed
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: "*.${domain_name}"
    allowedRoutes:
      namespaces:
        from: All
  - name: https
    protocol: HTTPS
    port: 443
    hostname: "*.${domain_name}"
    allowedRoutes:
      namespaces:
        from: All
    tls:
      mode: Terminate
      certificateRefs:
      - name: main-cert
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: argocd-route
  namespace: argocd
spec:
  parentRefs:
  - name: main-gateway
    namespace: default
  hostnames:
  - "argocd.${domain_name}"
  rules:
  - backendRefs:
    - name: argocd-server
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: grafana-route
  namespace: monitoring
spec:
  parentRefs:
  - name: main-gateway
    namespace: default
  hostnames:
  - "grafana.${domain_name}"
  rules:
  - backendRefs:
    - name: monitoring-grafana
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: prometheus-route
  namespace: monitoring
spec:
  parentRefs:
  - name: main-gateway
    namespace: default
  hostnames:
  - "prometheus.${domain_name}"
  rules:
  - backendRefs:
    - name: monitoring-kube-prometheus-prometheus
      port: 9090
