# Case Study: GKE GitOps Troubleshooting (Interview-Story)
**Datum:** 04.04.2026
**Themen:** #Interview #GKE #GitOps #ProblemSolving #SRE
**Kontext:** Diese Story basiert auf dem [[202604041930-gke-plattform-fixes-incident-report|Incident vom 04.04.2026]].

---

## Situation (S)
In einem GKE-Cluster (Google Kubernetes Engine) kam es zu einem Totalausfall der externen Erreichbarkeit für ArgoCD und Gitea. Das System nutzt einen GitOps-Ansatz (App-of-Apps), bei dem die Infrastruktur-Komponenten sich gegenseitig blockierten.

## Aufgabe (T)
Identifizierung und Auflösung einer kaskadierenden Fehlerkette:
1. SSL-Zertifikate wurden nicht ausgestellt (Cert-Manager).
2. Cloud Gateway erhielt keine IP-Adresse.
3. DNS-Einträge wurden nicht aktualisiert (External-DNS).
4. Core-Services (Gitea) befanden sich in einer Boot-Schleife.

## Aktion (A)
1. **Zirkuläre Abhängigkeiten aufgelöst:** Analyse der Log-Files ergab, dass Cert-Manager auf Monitoring-CRDs wartete, die selbst nicht installiert werden konnten. Ich habe die Abhängigkeiten durch `kubectl patch` manuell entkoppelt, um den Cert-Manager-Sync zu erzwingen.
2. **DNS-Owner-Alignment:** Identifikation eines Konfigurations-Mismatches zwischen der lokalen GitOps-Konfiguration (`txtOwnerId`) und den bestehenden Ressourcen in der Cloud DNS Zone. Manuelle Bereinigung der Cloud-Ressourcen via `gcloud`, um die Automatisierung wieder zu befähigen.
3. **Konfigurations-Restrukturierung:** Korrektur der Gitea `values.yaml` an die Struktur des Upstream-Charts und Anpassung der ArgoCD Sync-Optionen (Deaktivierung von Server-Side-Apply), um Schema-Konflikte zu lösen.

## Ergebnis (R)
- **Wiederherstellung:** Alle Dienste waren innerhalb kurzer Zeit wieder unter HTTPS erreichbar.
- **Nachhaltigkeit:** Überführung der Live-Patches in den GitOps-Code, um Idempotenz für zukünftige `terraform destroy && apply` Zyklen sicherzustellen.
- **Learning:** Infrastruktur als State-Machine verstehen – manchmal muss man das System manuell in einen stabilen Zwischenzustand bringen, damit die Automatisierung (ArgoCD) wieder übernehmen kann.

---
**Verknüpfte Notiz:** [[202604041930-gke-plattform-fixes-incident-report|Detaillierter Incident Report 04.04.2026]]
