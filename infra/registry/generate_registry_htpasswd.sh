#!/bin/bash
set -euo pipefail

# Note: .env.sample already has an htpasswd generated for use, this is just to show how to generate it
echo "WARNING: .env.sample already has an htpasswd generated for use, this is just read only, do not change it unless you know what you are doing."

# ----------------------
# Configuration
# ----------------------
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
# Validate required credentials
# ----------------------
for var in REGISTRY_USER REGISTRY_PASS; do
  if [ -z "${!var}" ]; then
    echo "$var must be set in .env"
    exit 1
  fi
done

# ----------------------
# Generate htpasswd entry using Docker
# ----------------------
HTPASSWD=$(docker run --rm httpd:2.4-alpine htpasswd -nbB "$REGISTRY_USER" "$REGISTRY_PASS")
echo "$HTPASSWD"