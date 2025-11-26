#!/bin/bash
# Cria um novo cliente com toda a estrutura necessária

set -e

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "❌ Uso: ./scripts/create-client.sh <nome-cliente> <firebase-project-id> <gcp-region>"
    echo "Exemplo: ./scripts/create-client.sh clinica-vet veterinary-clinic-abc southamerica-east1"
    exit 1
fi

CLIENTE_NAME=$1
FIREBASE_PROJECT=$2
REGION=$3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CLIENTE_DIR="$ROOT_DIR/clientes/$CLIENTE_NAME"

if [ -d "$CLIENTE_DIR" ]; then
    echo "❌ Cliente '$CLIENTE_NAME' já existe!"
    exit 1
fi

echo "🚀 Criando novo cliente: $CLIENTE_NAME"
echo "  Firebase Project: $FIREBASE_PROJECT"
echo "  Region: $REGION"
echo ""

# 1. Criar estrutura de pastas
echo "📁 Criando estrutura de pastas..."
mkdir -p "$CLIENTE_DIR/backend"
mkdir -p "$CLIENTE_DIR/frontend"

# 2. Copiar backend-core
echo "📦 Copiando backend-core..."
rsync -a --exclude='__pycache__' --exclude='*.pyc' "$ROOT_DIR/backend-core/" "$CLIENTE_DIR/backend/"

# 3. Copiar frontend-core
echo "📦 Copiando frontend-core..."
rsync -a \
    --exclude='build' \
    --exclude='.dart_tool' \
    --exclude='.flutter-plugins' \
    --exclude='.flutter-plugins-dependencies' \
    --exclude='.firebase' \
    "$ROOT_DIR/frontend-core/" "$CLIENTE_DIR/frontend/"

# 4. Gerar chaves VAPID
echo "🔑 Gerando chaves VAPID para Web Push..."
VAPID_KEYS=$(python3 "$SCRIPT_DIR/generate-vapid-keys.py" 2>/dev/null | grep -A 4 "VAPID_PRIVATE_KEY:")
VAPID_PRIVATE=$(echo "$VAPID_KEYS" | grep -A 0 "VAPID_PRIVATE_KEY:" | tail -n 1)
VAPID_PUBLIC=$(echo "$VAPID_KEYS" | grep -A 0 "VAPID_PUBLIC_KEY:" | tail -n 1)

if [ -z "$VAPID_PRIVATE" ] || [ -z "$VAPID_PUBLIC" ]; then
    echo "⚠️  Falha ao gerar chaves VAPID automaticamente."
    echo "   Você precisará gerar manualmente usando: python3 scripts/generate-vapid-keys.py"
    VAPID_PRIVATE="GENERATE_VAPID_KEYS"
    VAPID_PUBLIC="GENERATE_VAPID_KEYS"
fi

# 5. Criar backend config.yaml
echo "⚙️  Criando backend config.yaml..."
cat > "$CLIENTE_DIR/backend/config.yaml" << EOF
client_name: "$CLIENTE_NAME"
firebase_project_id: "$FIREBASE_PROJECT"
gcp_project_id: "$FIREBASE_PROJECT"
region: "$REGION"
service_name: "${CLIENTE_NAME}-backend"
secret_name: "firebase-admin-credentials-${CLIENTE_NAME}"
allow_unauthenticated: true

# VAPID keys for Web Push Notifications (unique per client)
vapid_private_key: "$VAPID_PRIVATE"
vapid_public_key: "$VAPID_PUBLIC"
vapid_claims_email: "mailto:suporte@${CLIENTE_NAME}.com.br"
EOF

# 6. Gerar negocioId único (usa timestamp + random)
NEGOCIO_ID=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
echo "🆔 Negócio ID gerado: $NEGOCIO_ID"

# 7. Criar frontend app_config.dart
echo "⚙️  Criando frontend app_config.dart..."
mkdir -p "$CLIENTE_DIR/frontend/lib/config"
cat > "$CLIENTE_DIR/frontend/lib/config/app_config.dart" << EOF
// lib/config/app_config.dart
// Configuração específica para $CLIENTE_NAME

class AppConfig {
  // URL do backend API
  static const String apiBaseUrl = 'https://${CLIENTE_NAME}-backend-REPLACE_PROJECT_NUMBER.${REGION}.run.app';

  // Nome do cliente (para exibição)
  static const String clientName = '$CLIENTE_NAME';

  // ID do negócio no Firestore (específico por cliente)
  static const String negocioId = '$NEGOCIO_ID';

  // Verifica se a configuração foi feita corretamente
  static bool get isConfigured {
    return !apiBaseUrl.contains('REPLACE') &&
           !clientName.contains('REPLACE') &&
           !negocioId.contains('REPLACE');
  }
}
EOF

# 8. Criar .firebaserc
echo "⚙️  Criando .firebaserc..."
cat > "$CLIENTE_DIR/frontend/.firebaserc" << EOF
{
  "projects": {
    "default": "$FIREBASE_PROJECT"
  }
}
EOF

# 9. Criar firebase.json
echo "⚙️  Criando firebase.json..."
cat > "$CLIENTE_DIR/frontend/firebase.json" << EOF
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
EOF

echo ""
echo "✅ Cliente $CLIENTE_NAME criado com sucesso!"
echo ""
echo "📋 Próximos passos:"
echo ""
echo "1. Configure o Firebase Project '$FIREBASE_PROJECT':"
echo "   - Crie o projeto no Firebase Console"
echo "   - Configure Firebase Authentication (Email/Password)"
echo "   - Configure Cloud Firestore"
echo "   - Rode 'flutterfire configure' no diretório frontend/"
echo ""
echo "2. Configure os recursos GCP (veja PLANO.md):"
echo "   - Enable APIs (cloudkms, secretmanager)"
echo "   - Create KMS keyring and crypto key"
echo "   - Create Firebase Admin service account"
echo "   - Create Secret Manager secret"
echo ""
echo "3. Crie o documento do negócio no Firestore:"
echo "   - Collection: negocios"
echo "   - Document ID: $NEGOCIO_ID"
echo "   - Campos: { nome: '$CLIENTE_NAME', tipo: 'clinica', ativo: true }"
echo ""
echo "4. Crie o usuário admin no Firebase Auth:"
echo "   - Email: admin@com.br"
echo "   - Password: 123456 (ou outra senha)"
echo ""
echo "5. Crie o usuário admin no Firestore:"
echo "   - Collection: usuarios"
echo "   - Campos obrigatórios:"
echo "     - email: 'admin@com.br'"
echo "     - firebase_uid: '<uid do Firebase Auth>'"
echo "     - nome: 'Admin'"
echo "     - roles: { '$NEGOCIO_ID': 'admin' }"
echo ""
echo "6. Atualize o apiBaseUrl no app_config.dart com o PROJECT_NUMBER correto"
echo ""
echo "7. Deploy:"
echo "   ./scripts/deploy-backend.sh $CLIENTE_NAME"
echo "   ./scripts/deploy-frontend.sh $CLIENTE_NAME"
echo ""
