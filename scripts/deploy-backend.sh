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
FIREBASE_PROJECT=$(grep 'firebase_project_id:' config.yaml | awk '{print $2}' | tr -d '"')
SERVICE_NAME=$(grep 'service_name:' config.yaml | awk '{print $2}' | tr -d '"')
REGION=$(grep 'region:' config.yaml | awk '{print $2}' | tr -d '"')
SECRET_NAME=$(grep 'secret_name:' config.yaml | awk '{print $2}' | tr -d '"')

# Lê VAPID keys do config.yaml (se existirem)
VAPID_PRIVATE=$(grep 'vapid_private_key:' config.yaml | awk '{print $2}' | tr -d '"')
VAPID_PUBLIC=$(grep 'vapid_public_key:' config.yaml | awk '{print $2}' | tr -d '"')
VAPID_EMAIL=$(grep 'vapid_claims_email:' config.yaml | awk '{print $2}' | tr -d '"')

# Lê Cloud Storage bucket do config.yaml (se existir)
CLOUD_STORAGE_BUCKET=$(grep 'cloud_storage_bucket:' config.yaml | awk '{print $2}' | tr -d '"')

echo "  Project: $GCP_PROJECT"
echo "  Service: $SERVICE_NAME"
echo "  Region: $REGION"
echo "  Firebase Project: $FIREBASE_PROJECT"
echo "  Secret: $SECRET_NAME"

if [ -n "$CLOUD_STORAGE_BUCKET" ]; then
    echo "  Cloud Storage Bucket: $CLOUD_STORAGE_BUCKET ✓"
else
    echo "  Cloud Storage Bucket: Not configured (file uploads will not work)"
fi

if [ -n "$VAPID_PRIVATE" ] && [ -n "$VAPID_PUBLIC" ]; then
    echo "  VAPID Keys: Configured ✓"
else
    echo "  VAPID Keys: Not configured (notifications will not work)"
fi

# Constrói o nome do recurso KMS
KMS_KEY_NAME="projects/$GCP_PROJECT/locations/$REGION/keyRings/$CLIENTE-keyring/cryptoKeys/$CLIENTE-crypto-key"

# Monta as variáveis de ambiente
ENV_VARS="KMS_CRYPTO_KEY_NAME=$KMS_KEY_NAME,FIREBASE_PROJECT_ID=$FIREBASE_PROJECT,SECRET_NAME=$SECRET_NAME"

# Adiciona Cloud Storage bucket se existir
if [ -n "$CLOUD_STORAGE_BUCKET" ]; then
    ENV_VARS="$ENV_VARS,CLOUD_STORAGE_BUCKET_NAME=$CLOUD_STORAGE_BUCKET"
fi

# Adiciona VAPID keys se existirem
if [ -n "$VAPID_PRIVATE" ] && [ -n "$VAPID_PUBLIC" ]; then
    ENV_VARS="$ENV_VARS,VAPID_PRIVATE_KEY=$VAPID_PRIVATE,VAPID_PUBLIC_KEY=$VAPID_PUBLIC"
    if [ -n "$VAPID_EMAIL" ]; then
        ENV_VARS="$ENV_VARS,VAPID_CLAIMS_EMAIL=$VAPID_EMAIL"
    fi
fi

/opt/homebrew/bin/gcloud run deploy "$SERVICE_NAME" \
    --source . \
    --region="$REGION" \
    --project="$GCP_PROJECT" \
    --allow-unauthenticated \
    --set-env-vars="$ENV_VARS"

echo "✅ Backend de $CLIENTE deployado com sucesso!"
