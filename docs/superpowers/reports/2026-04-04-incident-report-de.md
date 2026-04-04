# Incident Report & Dokumentation der Plattform-Fixes
**Datum:** 04.04.2026
**Status:** Gelöst (Live im Cluster gepatcht)
**Tags:** #GKE #ArgoCD #CertManager #Gitea #Kubernetes #Troubleshooting

## 1. Problemübersicht
Die Hauptseite `https://argocd.hannesalbeiro.com/` war nicht erreichbar. Dies lag an einer Kette von Abhängigkeiten und Konfigurationsfehlern über mehrere Plattform-Komponenten hinweg:
- **Cert-Manager** war blockiert, wodurch keine SSL-Zertifikate ausgestellt wurden.
- Das **GKE Gateway** blieb im Status "Waiting for Controller", da das Zertifikat-Secret fehlte.
- **External-DNS** konnte die DNS-Einträge nicht aktualisieren (Konfigurationsfehler).
- **Gitea** und das **Monitoring** befanden sich in Absturzschleifen oder Sync-Fehlern.

---

## 2. Ursachen & Lösungen

### A. Cert-Manager / Monitoring Deadlock
- **Ursache:** `cert-manager` wollte einen Prometheus `ServiceMonitor` erstellen, bevor die Monitoring-CRDs installiert waren. Die `monitoring`-App wiederum schlug fehl, da die Admission-Webhooks Ressourcenkonflikte verursachten ("ClusterRole already exists").
- **Fix:** 
    1. `cert-manager` gepatcht, um `ServiceMonitor` initial zu deaktivieren.
    2. `monitoring` gepatcht, um `prometheusOperator.admissionWebhooks.enabled` zu deaktivieren.
- **Ergebnis:** Cert-Manager konnte starten und das Wildcard-Zertifikat erstellen.

### B. GKE Gateway & DNS Erreichbarkeit
- **Ursache:** Das Gateway erhielt keine IP, solange das Zertifikat fehlte. Nachdem die IP da war, verweigerte `external-dns` das Update, weil:
    1. Die `txtOwnerId` auf `txt2md-cluster-v2` stand, die alten Einträge in Google Cloud aber `txt2md-cluster` gehörten.
    2. Der `txtPrefix` falsch konfiguriert war.
- **Fix:** 
    1. `external-dns` auf `txtOwnerId: "txt2md-cluster"` und leeren Präfix umgestellt.
    2. Konfliktbehaftete TXT-Einträge manuell via `gcloud` in der Cloud bereinigt.
- **Ergebnis:** Die DNS-Einträge für `argocd` und `gitea` zeigen nun korrekt auf die Gateway-IP (`130.211.30.135`).

### C. Gitea Init:CrashLoopBackOff
- **Ursache:** Das Gitea Helm-Chart erwartete die Konfiguration unter einem `gitea:`-Key in der `values.yaml`. Unsere Datei hatte sie auf der obersten Ebene, weshalb die Datenbank-Einstellungen in der `app.ini` fehlten.
- **Fix:** 
    1. `platform/gitea/values.yaml` restrukturiert (alles in einen `gitea:` Block verschoben).
    2. `ServerSideApply` in ArgoCD für Gitea deaktiviert, um Schema-Fehler zu vermeiden.
- **Ergebnis:** Gitea startete erfolgreich und erstellte den Admin-User.

---

## 3. Troubleshooting Plan (für die Zukunft)

Wenn der Sync in ArgoCD "hängt":
1. **CRD-Abhängigkeiten prüfen:** Sicherstellen, dass keine Ressourcen (wie `ServiceMonitor`) erstellt werden, bevor der zugehörige Operator bereit ist.
2. **ArgoCD Sync-Details:** `kubectl get application <name> -n argocd -o yaml` prüfen, insbesondere `status.syncResult`.
3. **External-DNS Logs:** Bei DNS-Problemen: `kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns`. Suche nach "Skipping endpoint ... because owner id does not match".
4. **Gateway Status:** `kubectl get gateway -n kube-system external-http -o yaml` prüfen. Wenn `Programmed` auf `Unknown` steht, liegt es meist am TLS/Zertifikat.

---

## 4. Funktioniert Terraform Apply nach einem Destroy?

**WICHTIG:** Aktuell würde ein `terraform apply` nach einem `destroy` **noch fehlschlagen**, da die Fixes nur lokal und live im Cluster existieren.

### Grund:
Die ArgoCD `root-app` zieht die Konfiguration direkt von GitHub. Da ich (der Agent) keine Push-Rechte für dein Repository habe, liegt auf GitHub noch der alte, fehlerhafte Stand.

### So machst du es "Terraform-sicher":
Damit ein automatischer Wiederaufbau funktioniert, musst du:
1. **Änderungen pushen:** Übertrage meine lokalen Änderungen auf GitHub:
   ```bash
   git push origin master
   ```
2. **selfHeal aktivieren:** Danach kannst du die automatische Korrektur in ArgoCD wieder einschalten:
   ```bash
   kubectl patch application root-app -n argocd --type merge -p '{"spec": {"syncPolicy": {"automated": {"selfHeal": true}}}}'
   ```

**Job-Interview Transfer:** Diese Problemlösung ist als STAR-Story dokumentiert unter: [[202604041945-interview-case-study-gke-gitops]].
