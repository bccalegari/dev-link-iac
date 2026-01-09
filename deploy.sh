#!/bin/bash
set -euo pipefail

echo "Starting dev-link deployment script..."

# ----------------------
# Configuration
# ----------------------
NAMESPACE="devlink"
PUSH_IMAGES=${PUSH_IMAGES:-false} # Use: PUSH_IMAGES=true ./deploy.sh

# ----------------------
# Deploy Nginx Ingress Controller
# ----------------------
if kubectl get namespace ingress-nginx >/dev/null 2>&1; then
  echo "Nginx Ingress Controller already deployed, skipping..."
else
  echo "Deploying Nginx Ingress Controller v1.14..."
  kubectl apply -f ./infra/nginx-ingress/nginx-ingress.yaml
  kubectl rollout status deployment -n ingress-nginx -l app.kubernetes.io/component=controller
fi

# ----------------------
# Deploy Terraform Resources
# ----------------------
echo "Deploying Terraform Resources..."
terraform init
terraform plan

if [ "$PUSH_IMAGES" = "true" ]; then
    terraform apply -auto-approve &
    echo "Terraform apply started in background with PID $!"
    TF_PID=$!

    echo "PUSH_IMAGES is true, proceeding to push custom images..."

    until kubectl get namespace $NAMESPACE >/dev/null 2>&1; do
        echo "Waiting for namespace $NAMESPACE to be created..."
        sleep 5
    done

    echo "Waiting for Registry deployment to be ready..."
    kubectl rollout status deployment/registry -n $NAMESPACE
    kubectl wait --for=condition=available deployment/registry -n $NAMESPACE --timeout=120s

    echo "Pushing custom images to Registry..."
    cd ./infra/buildah && ./build.sh
    cd ../..

    echo "Custom images pushed successfully."

    wait $TF_PID
    wait
else
    echo "PUSH_IMAGES is false, skipping image push..."
    terraform apply -auto-approve
fi

echo "dev-link deployment script completed successfully!"