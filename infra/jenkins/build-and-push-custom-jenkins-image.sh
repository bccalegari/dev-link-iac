#!/bin/bash
set -euo pipefail

# ----------------------
# Configuration
# ----------------------
IMAGE_NAME="devlink-jenkins"
TAG="latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../../.env"

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
# Build Docker image
# ----------------------
docker build -t ${REGISTRY_URL}/${IMAGE_NAME}:${TAG} .

# ----------------------
# Login and push
# ----------------------
echo "$REGISTRY_PASS" | docker login "$REGISTRY_URL" -u "$REGISTRY_USER" --password-stdin
docker push ${REGISTRY_URL}/${IMAGE_NAME}:${TAG}
echo "Image ${REGISTRY_URL}/${IMAGE_NAME}:${TAG} built and pushed successfully!"