#!/bin/bash
# Deploy frontend de um cliente específico

set -e

if [ -z "$1" ]; then
    echo "❌ Uso: ./scripts/deploy-frontend.sh <nome-cliente>"
    echo "Exemplo: ./scripts/deploy-frontend.sh clinica-medica"
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

if [ ! -f "$CLIENTE_DIR/frontend/.firebaserc" ]; then
    echo "❌ Arquivo .firebaserc não encontrado em clientes/$CLIENTE/frontend/"
    exit 1
fi

echo "🚀 Deploying frontend para $CLIENTE..."

cd "$CLIENTE_DIR/frontend"

# Build Flutter web
echo "  📦 Building Flutter web..."
/Users/joseairton/Flutter/flutter/bin/flutter build web

# Deploy to Firebase Hosting
echo "  🔥 Deploying to Firebase Hosting..."
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
/Users/joseairton/.nvm/versions/node/v22.20.0/bin/firebase deploy --only hosting

echo "✅ Frontend de $CLIENTE deployado com sucesso!"
