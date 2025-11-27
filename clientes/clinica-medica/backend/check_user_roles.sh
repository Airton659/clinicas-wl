#!/bin/bash
#
# Script para verificar roles de um usuário
#
# Uso: ./check_user_roles.sh <nome-cliente> <email> <negocio-id>
#

set -e

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "❌ Erro: Parâmetros insuficientes"
    echo ""
    echo "Uso: ./check_user_roles.sh <nome-cliente> <email> <negocio-id>"
    echo 'Exemplo: ./check_user_roles.sh clinica-medica "admin@com.br" "UtFHQf3lwIHfMmf8wHDu"'
    exit 1
fi

CLIENT_NAME=$1
EMAIL=$2
NEGOCIO_ID=$3
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$SCRIPT_DIR/../clientes/$CLIENT_NAME"
CONFIG_FILE="$CLIENT_DIR/backend/config.yaml"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  VERIFICAR ROLES DE USUÁRIO                                    ║"
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

GCP_PROJECT_ID=$(grep 'gcp_project_id:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
SECRET_NAME=$(grep 'secret_name:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')

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

echo ""

# Executar verificação
python3 "$SCRIPT_DIR/check_user_roles.py" "$CRED_FILE" "$EMAIL" "$NEGOCIO_ID"

# Cleanup
rm -rf "$TMP_DIR"

echo ""
