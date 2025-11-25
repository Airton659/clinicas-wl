#!/bin/bash
# Deploy completo (backend + frontend) de um cliente

set -e

if [ -z "$1" ]; then
    echo "❌ Uso: ./scripts/deploy-all.sh <nome-cliente>"
    echo "Exemplo: ./scripts/deploy-all.sh clinica-medica"
    exit 1
fi

CLIENTE=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Deploy completo de $CLIENTE..."
echo ""

# Deploy backend
echo "=== BACKEND ==="
"$SCRIPT_DIR/deploy-backend.sh" "$CLIENTE"

echo ""
echo "=== FRONTEND ==="
"$SCRIPT_DIR/deploy-frontend.sh" "$CLIENTE"

echo ""
echo "🎉 Deploy completo de $CLIENTE finalizado!"
