#!/bin/bash
set -euo pipefail

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
# Validate required registry credentials
# ----------------------
for var in REGISTRY_USER REGISTRY_PASS REGISTRY_EMAIL REGISTRY_URL REGISTRY_HTPASSWD; do
  if [ -z "${!var}" ]; then
    echo "$var must be set in .env"
    exit 1
  fi
done

# ----------------------
# Generate base64-encoded auth string for Docker registry
# ----------------------
AUTH_BASE64=$(echo -n "${REGISTRY_USER}:${REGISTRY_PASS}" | base64)

# ----------------------
# Generate Docker config JSON using jq
# ----------------------
# This creates the structure used by Kubernetes secrets or Docker clients
DOCKERCONFIGJSON=$(jq -n \
  --arg user "$REGISTRY_USER" \
  --arg pass "$REGISTRY_PASS" \
  --arg email "$REGISTRY_EMAIL" \
  --arg url "$REGISTRY_URL" \
  --arg auth "$AUTH_BASE64" \
  '{
    auths: {
      ($url): {
        username: $user,
        password: $pass,
        email: $email,
        auth: $auth
      }
    }
  }' | jq -c .)

BASIC_AUTH=$(jq -n \
  --arg user "$REGISTRY_USER" \
  --arg pass "$REGISTRY_PASS" \
  '{ username: $user, password: $pass }' | jq -c .)

# ----------------------
# Combine htpasswd and Docker config JSON into final JSON
# ----------------------
jq -n \
  --arg htpasswd "$REGISTRY_HTPASSWD" \
  --arg dockerconfigjson "$DOCKERCONFIGJSON" \
  --arg basic_auth "$BASIC_AUTH" \
  '{
    htpasswd: $htpasswd,
    dockerconfigjson: $dockerconfigjson,
    basic_auth: $basic_auth
  }'