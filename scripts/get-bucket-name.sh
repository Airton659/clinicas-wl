#!/bin/bash
# Script auxiliar para obter o nome do bucket Cloud Storage de um projeto Firebase

set -e

if [ -z "$1" ]; then
    echo "❌ Uso: ./scripts/get-bucket-name.sh <gcp-project-id>"
    echo "Exemplo: ./scripts/get-bucket-name.sh concierge-health-pilot"
    exit 1
fi

PROJECT_ID=$1

echo "🔍 Buscando buckets do projeto: $PROJECT_ID"
echo ""

BUCKETS=$(/opt/homebrew/bin/gcloud storage buckets list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null)

if [ -z "$BUCKETS" ]; then
    echo "❌ Nenhum bucket encontrado no projeto $PROJECT_ID"
    echo ""
    echo "💡 Dica: O Firebase geralmente cria um bucket automaticamente no formato:"
    echo "   <project-id>.firebasestorage.app"
    echo ""
    echo "Se o projeto ainda não tem bucket, você pode criar um no Firebase Console:"
    echo "https://console.firebase.google.com/project/$PROJECT_ID/storage"
    exit 1
fi

echo "✅ Buckets encontrados:"
echo ""

# Lista os buckets encontrados
while IFS= read -r bucket; do
    # Destaca o bucket do Firebase (geralmente termina com .firebasestorage.app)
    if [[ "$bucket" == *".firebasestorage.app" ]]; then
        echo "  🔥 $bucket  (Firebase Storage - USE ESTE)"
    else
        echo "  📦 $bucket"
    fi
done <<< "$BUCKETS"

echo ""
echo "💡 Use o bucket do Firebase Storage (marcado com 🔥) no config.yaml:"
echo ""
echo "cloud_storage_bucket: \"<nome-do-bucket-firebase>\""
echo ""
