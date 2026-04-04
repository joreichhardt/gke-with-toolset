#!/bin/bash
set -e

# Konfiguration
PROJECT_ID="project-84ddd43d-e408-4cb9-8cb"
REGION="europe-west3"
REPO_NAME="txt2md-repo"
IMAGE_NAME="txt2md"
GITHUB_REPO="https://github.com/joreichhardt/txt2md.git"

echo "🚀 Starte Image-Bootstrap für $IMAGE_NAME..."

# Temporäres Verzeichnis für den Build
TEMP_DIR=$(mktemp -d)
echo "📂 Klonen des Repositories nach $TEMP_DIR..."
git clone $GITHUB_REPO $TEMP_DIR

# Build mit Google Cloud Build (kein lokales Docker benötigt)
echo "🏗️ Starte Google Cloud Build..."
gcloud builds submit $TEMP_DIR \
    --tag "$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/$IMAGE_NAME:latest" \
    --project=$PROJECT_ID

echo "✅ Image erfolgreich gebaut und in Artifact Registry gepusht!"
echo "🔗 Image-Pfad: $REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/$IMAGE_NAME:latest"

# Cleanup
rm -rf $TEMP_DIR

echo "🔄 Trigger ArgoCD Refresh..."
kubectl patch application txt2md-app -n argocd --type merge -p '{"metadata": {"annotations": {"argocd.argoproj.io/refresh": "hard"}}}'

echo "🏁 Fertig! Die Pods sollten in Kürze starten."
