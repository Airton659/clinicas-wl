#!/bin/bash
set -e

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Uso: ./cleanup_invalid_roles.sh <nome-cliente> <negocio-id>"
    exit 1
fi

CLIENT_NAME=$1
NEGOCIO_ID=$2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$SCRIPT_DIR/../clientes/$CLIENT_NAME"
CONFIG_FILE="$CLIENT_DIR/backend/config.yaml"

GCP_PROJECT_ID=$(grep 'gcp_project_id:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
SECRET_NAME=$(grep 'secret_name:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')

TMP_DIR=$(mktemp -d)
CRED_FILE="$TMP_DIR/firebase-credentials.json"

/opt/homebrew/bin/gcloud secrets versions access latest \
    --secret="$SECRET_NAME" \
    --project="$GCP_PROJECT_ID" \
    > "$CRED_FILE"

python3 "$SCRIPT_DIR/cleanup_invalid_roles.py" "$CRED_FILE" "$NEGOCIO_ID"

rm -rf "$TMP_DIR"
