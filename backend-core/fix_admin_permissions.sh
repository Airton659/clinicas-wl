#!/bin/bash
#
# Script para corrigir permissões do perfil Admin usando Secret Manager
#
# Uso: ./fix_admin_permissions.sh <nome-cliente> <negocio-id>
# Exemplo: ./fix_admin_permissions.sh clinica-medica UtFHQf3lwIHfMmf8wHDu
#

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "❌ Erro: Parâmetros insuficientes"
    echo ""
    echo "Uso: ./fix_admin_permissions.sh <nome-cliente> <negocio-id>"
    echo "Exemplo: ./fix_admin_permissions.sh clinica-medica UtFHQf3lwIHfMmf8wHDu"
    exit 1
fi

CLIENT_NAME=$1
NEGOCIO_ID=$2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$SCRIPT_DIR/../clientes/$CLIENT_NAME"
CONFIG_FILE="$CLIENT_DIR/backend/config.yaml"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  CORREÇÃO DE PERMISSÕES DO ADMIN                               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se cliente existe
if [ ! -d "$CLIENT_DIR" ]; then
    echo "❌ Erro: Cliente '$CLIENT_NAME' não encontrado"
    exit 1
fi

# Ler configurações
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Erro: config.yaml não encontrado"
    exit 1
fi

echo "📄 Lendo configurações..."

GCP_PROJECT_ID=$(grep 'gcp_project_id:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
SECRET_NAME=$(grep 'secret_name:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')

echo "  ✓ GCP Project: $GCP_PROJECT_ID"
echo "  ✓ Secret Name: $SECRET_NAME"
echo "  ✓ Negócio ID: $NEGOCIO_ID"
echo ""

# Criar temp dir
TMP_DIR=$(mktemp -d)
CRED_FILE="$TMP_DIR/firebase-credentials.json"

echo "🔐 Baixando credenciais..."

# Baixar credenciais
/opt/homebrew/bin/gcloud secrets versions access latest \
    --secret="$SECRET_NAME" \
    --project="$GCP_PROJECT_ID" \
    > "$CRED_FILE"

if [ ! -s "$CRED_FILE" ]; then
    echo "❌ Erro ao baixar credenciais"
    rm -rf "$TMP_DIR"
    exit 1
fi

echo "  ✓ Credenciais baixadas"
echo ""

# Executar correção
echo "🚀 Executando correção..."
echo ""

python3 "$SCRIPT_DIR/fix_admin_permissions.py" "$CRED_FILE" "$NEGOCIO_ID"

# Cleanup
echo ""
echo "🧹 Limpando arquivos temporários..."
rm -rf "$TMP_DIR"

echo ""
echo "✅ Processo concluído!"
