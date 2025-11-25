#!/bin/bash
# Deploy backend de um cliente específico

set -e

if [ -z "$1" ]; then
    echo "❌ Uso: ./scripts/deploy-backend.sh <nome-cliente>"
    echo "Exemplo: ./scripts/deploy-backend.sh clinica-medica"
    exit 1
fi

CLIENTE=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CLIENTE_DIR="$ROOT_DIR/clientes/$CLIENTE"

if [ ! -d "$CLIENTE_DIR" ]; then
    echo "❌ Cliente '$CLIENTE' não encontrado em clientes/"
    exit 1
fi

if [ ! -f "$CLIENTE_DIR/backend/config.yaml" ]; then
    echo "❌ Arquivo config.yaml não encontrado em clientes/$CLIENTE/backend/"
    exit 1
fi

echo "🚀 Deploying backend para $CLIENTE..."

cd "$CLIENTE_DIR/backend"

# Lê configurações do config.yaml
GCP_PROJECT=$(grep 'gcp_project_id:' config.yaml | awk '{print $2}' | tr -d '"')
SERVICE_NAME=$(grep 'service_name:' config.yaml | awk '{print $2}' | tr -d '"')
REGION=$(grep 'region:' config.yaml | awk '{print $2}' | tr -d '"')

echo "  Project: $GCP_PROJECT"
echo "  Service: $SERVICE_NAME"
echo "  Region: $REGION"

/opt/homebrew/bin/gcloud run deploy "$SERVICE_NAME" \
    --source . \
    --region="$REGION" \
    --project="$GCP_PROJECT" \
    --allow-unauthenticated

echo "✅ Backend de $CLIENTE deployado com sucesso!"
