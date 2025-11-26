#!/bin/bash
#
# Script para popular permissões usando credenciais do Secret Manager
#
# Uso: ./seed_permissions_gcloud.sh <nome-cliente>
# Exemplo: ./seed_permissions_gcloud.sh clinica-medica
#

set -e

if [ -z "$1" ]; then
    echo "❌ Erro: Nome do cliente não fornecido"
    echo ""
    echo "Uso: ./seed_permissions_gcloud.sh <nome-cliente>"
    echo "Exemplo: ./seed_permissions_gcloud.sh clinica-medica"
    exit 1
fi

CLIENT_NAME=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$SCRIPT_DIR/../clientes/$CLIENT_NAME"
CONFIG_FILE="$CLIENT_DIR/backend/config.yaml"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  SEED DE PERMISSÕES - VIA GCLOUD SECRET MANAGER               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se cliente existe
if [ ! -d "$CLIENT_DIR" ]; then
    echo "❌ Erro: Cliente '$CLIENT_NAME' não encontrado em clientes/"
    exit 1
fi

# Ler configurações do config.yaml
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Erro: Arquivo config.yaml não encontrado em $CLIENT_DIR/backend/"
    exit 1
fi

echo "📄 Lendo configurações de $CONFIG_FILE..."

FIREBASE_PROJECT_ID=$(grep 'firebase_project_id:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
GCP_PROJECT_ID=$(grep 'gcp_project_id:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
SECRET_NAME=$(grep 'secret_name:' "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')

if [ -z "$FIREBASE_PROJECT_ID" ] || [ -z "$GCP_PROJECT_ID" ] || [ -z "$SECRET_NAME" ]; then
    echo "❌ Erro: Configurações incompletas no config.yaml"
    echo "   Certifique-se que firebase_project_id, gcp_project_id e secret_name estão configurados"
    exit 1
fi

echo "  ✓ Firebase Project: $FIREBASE_PROJECT_ID"
echo "  ✓ GCP Project: $GCP_PROJECT_ID"
echo "  ✓ Secret Name: $SECRET_NAME"
echo ""

# Criar diretório temporário para credenciais
TMP_DIR=$(mktemp -d)
CRED_FILE="$TMP_DIR/firebase-credentials.json"

echo "🔐 Baixando credenciais do Secret Manager..."

# Baixar credenciais do Secret Manager
/opt/homebrew/bin/gcloud secrets versions access latest \
    --secret="$SECRET_NAME" \
    --project="$GCP_PROJECT_ID" \
    > "$CRED_FILE"

if [ ! -s "$CRED_FILE" ]; then
    echo "❌ Erro: Falha ao baixar credenciais do Secret Manager"
    rm -rf "$TMP_DIR"
    exit 1
fi

echo "  ✓ Credenciais baixadas com sucesso"
echo ""

# Criar script Python temporário que usa as credenciais
PYTHON_SCRIPT="$TMP_DIR/seed_temp.py"

cat > "$PYTHON_SCRIPT" <<'PYTHON_EOF'
import sys
import os
import firebase_admin
from firebase_admin import credentials, firestore

# Importar catálogo de permissões
sys.path.insert(0, os.path.dirname(__file__) + '/../')
from permissions_catalog import get_all_permissions

def seed_permissions(cred_file):
    """Popula permissões no Firestore"""
    try:
        # Inicializar Firebase
        cred = credentials.Certificate(cred_file)
        app = firebase_admin.initialize_app(cred)
        db = firestore.client(app=app)

        # Buscar permissões
        permissions = get_all_permissions()
        print(f"📋 Total de permissões: {len(permissions)}\n")

        created = 0
        updated = 0

        for perm in permissions:
            perm_id = perm["id"]
            perm_ref = db.collection("permissions").document(perm_id)
            perm_doc = perm_ref.get()

            if perm_doc.exists:
                perm_ref.set(perm)
                updated += 1
                print(f"  🔄 Atualizado: {perm_id}")
            else:
                perm_ref.set(perm)
                created += 1
                print(f"  ✅ Criado: {perm_id}")

        print(f"\n{'='*60}")
        print(f"📊 RESUMO:")
        print(f"{'='*60}")
        print(f"✅ Criadas:     {created}")
        print(f"🔄 Atualizadas: {updated}")
        print(f"{'='*60}")
        print(f"\n🎉 Seed concluído com sucesso!")

        firebase_admin.delete_app(app)

    except Exception as e:
        print(f"❌ Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    seed_permissions(sys.argv[1])
PYTHON_EOF

# Copiar permissions_catalog.py para temp dir
cp "$SCRIPT_DIR/permissions_catalog.py" "$TMP_DIR/"

# Executar seed
echo "🚀 Executando seed de permissões..."
echo ""

cd "$TMP_DIR"
python3 seed_temp.py "$CRED_FILE"

# Cleanup
echo ""
echo "🧹 Limpando arquivos temporários..."
rm -rf "$TMP_DIR"

echo ""
echo "✅ Processo concluído!"
PYTHON_EOF

chmod +x "$PYTHON_SCRIPT"

# Executar
python3 "$PYTHON_SCRIPT" "$CRED_FILE"

# Cleanup
echo ""
echo "🧹 Limpando arquivos temporários..."
rm -rf "$TMP_DIR"

echo ""
echo "✅ Processo concluído!"
