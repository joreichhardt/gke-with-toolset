#!/bin/bash

# Configuration from Terraform variables
export PROJECT_ID=$(cd terraform && terraform output -raw project_id 2>/dev/null || echo "project-84ddd43d-e408-4cb9-8cb")
export DOMAIN_NAME=$(cd terraform && terraform output -raw domain_name 2>/dev/null || echo "hannesalbeiro.com")

echo "Using Project: $PROJECT_ID"
echo "Using Domain: $DOMAIN_NAME"

# Function to apply manifests with envsubst
apply_template() {
    local file=$1
    echo "Applying $file..."
    envsubst < "$file" | kubectl apply -f -
}

# Apply base infrastructure
kubectl apply -f argocd/cert-manager-issuer.yaml

# Apply templated routes and apps
apply_template argocd/platform-routes.yaml
apply_template argocd/application.yaml
apply_template argocd/app/templates/deployment.yaml

echo "Bootstrap complete."
