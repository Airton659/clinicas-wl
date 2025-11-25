#!/bin/bash
# Sincroniza backend-core e frontend-core para todos os clientes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔄 Sincronizando cores para todos os clientes..."

for cliente_dir in "$ROOT_DIR"/clientes/*/; do
    if [ ! -d "$cliente_dir" ]; then
        continue
    fi

    cliente=$(basename "$cliente_dir")
    echo ""
    echo "📦 Sincronizando $cliente..."

    # Sincroniza backend
    if [ -d "$ROOT_DIR/backend-core" ]; then
        echo "  → Backend..."
        rsync -av --delete \
            --exclude='config.yaml' \
            --exclude='deploy.sh' \
            --exclude='.env' \
            --exclude='__pycache__' \
            --exclude='*.pyc' \
            "$ROOT_DIR/backend-core/" "$cliente_dir/backend/"
    fi

    # Sincroniza frontend
    if [ -d "$ROOT_DIR/frontend-core" ]; then
        echo "  → Frontend..."
        rsync -av --delete \
            --exclude='config.yaml' \
            --exclude='.firebaserc' \
            --exclude='firebase.json' \
            --exclude='build' \
            --exclude='.dart_tool' \
            --exclude='.flutter-plugins' \
            --exclude='.flutter-plugins-dependencies' \
            "$ROOT_DIR/frontend-core/" "$cliente_dir/frontend/"
    fi

    echo "  ✅ $cliente sincronizado"
done

echo ""
echo "🎉 Sincronização completa!"
