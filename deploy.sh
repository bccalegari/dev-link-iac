#!/bin/bash
set -euo pipefail

echo "Starting devlink deployment script..."

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

if [ "$PUSH_IMAGES" = "true" ]; then
    echo "PUSH_IMAGES is true, proceeding to push custom images..."

    # ----------------------
    # Configuration
    # ----------------------
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ENV_FILE="$SCRIPT_DIR/.env"

    # ----------------------
    # Load environment variables from .env file
    # ----------------------
    if [ ! -f "$ENV_FILE" ]; then
    echo ".env file not found at $ENV_FILE"
    exit 1
    fi

    # Export all variables in .env to environment
    set -a
    source "$ENV_FILE"
    set +a

    # ----------------------
    # Validate required registry credentials
    # ----------------------
    for var in REGISTRY_USER REGISTRY_PASS REGISTRY_URL; do
    if [ -z "${!var}" ]; then
        echo "$var must be set in .env"
        exit 1
    fi
    done

    # ----------------------
    # Deploy Terraform Registry
    # ----------------------
    echo "Deploying Terraform Registry..."
    terraform init
    terraform plan -target=module.registry
    terraform apply -target=module.registry -auto-approve

    echo "Waiting for Registry deployment to be ready..."
    kubectl rollout status deployment/registry -n $NAMESPACE
    kubectl wait --for=condition=available deployment/registry -n $NAMESPACE --timeout=120s

    echo "Pushing custom images to Registry..."

    if ! curl -u $REGISTRY_USER:$REGISTRY_PASS -s http://$REGISTRY_URL/v2/terraform-k8s/tags/list | grep latest >/dev/null; then
        echo "Pushing terraform-k8s image..."
        cd ./docker && ./build-and-push-custom-terraform-image.sh
    else
        echo "terraform-k8s already exists in registry"
    fi

    if ! curl -u $REGISTRY_USER:$REGISTRY_PASS -s http://$REGISTRY_URL/v2/devlink-jenkins/tags/list | grep latest >/dev/null; then
        echo "Pushing devlink-jenkins image..."
        cd ./jenkins && ./build-and-push-custom-jenkins-image.sh
    else
        echo "devlink-jenkins already exists in registry"
    fi

    echo "Custom images pushed successfully."

    # ----------------------
    # Deploy Jenkins
    # ----------------------
    echo "Deploying Jenkins..."
    terraform plan -target=module.jenkins
    terraform apply -target=module.jenkins -auto-approve
else
    echo "Skipping image push because PUSH_IMAGES is not true."

    # ----------------------
    # Deploy Terraform Resources
    # ----------------------
    echo "Deploying Terraform Resources..."
    terraform init
    terraform plan
    terraform apply -auto-approve
fi

echo "devlink deployment script completed successfully!"