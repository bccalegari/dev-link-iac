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
for var in JENKINS_USER JENKINS_PASS; do
  if [ -z "${!var}" ]; then
    echo "$var must be set in .env"
    exit 1
  fi
done

# ----------------------
# Generate Jenkins credentials JSON using jq
# ----------------------

jq -n \
  --arg username "$JENKINS_USER" \
  --arg password "$JENKINS_PASS" \
  '{
    username: $username,
    password: $password
  }'