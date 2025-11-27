#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Uso: ./create_super_admin.sh <nome-cliente>"
    exit 1
fi

CLIENT_NAME=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$SCRIPT_DIR/../clientes/$CLIENT_NAME"
CONFIG_FILE="$CLIENT_DIR/backend/config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Arquivo config.yaml não encontrado: $CONFIG_FILE"
    exit 1
fi

GCP_PROJECT_ID=$(grep 'gcp_project_id:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
SECRET_NAME=$(grep 'secret_name:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')

echo "🔧 Criando Super Admin padrão para cliente: $CLIENT_NAME"
echo "📦 Projeto GCP: $GCP_PROJECT_ID"
echo "🔐 Secret: $SECRET_NAME"
echo ""

TMP_DIR=$(mktemp -d)
CRED_FILE="$TMP_DIR/firebase-credentials.json"

/opt/homebrew/bin/gcloud secrets versions access latest \
    --secret="$SECRET_NAME" \
    --project="$GCP_PROJECT_ID" \
    > "$CRED_FILE"

python3 "$SCRIPT_DIR/create_default_super_admin.py" "$CRED_FILE"

rm -rf "$TMP_DIR"
