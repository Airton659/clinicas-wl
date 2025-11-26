#!/usr/bin/env python3
"""
Script de Seed - Popular Permissões no Firestore

IMPORTANTE: Este script deve ser executado UMA VEZ para cada cliente
para popular a collection 'permissions' com as 40 permissões genéricas.

Uso:
    python seed_permissions.py <nome-cliente>

Exemplo:
    python seed_permissions.py clinica-medica
"""

import sys
import os
from pathlib import Path

# Adicionar backend-core ao path
backend_core_path = Path(__file__).parent
sys.path.insert(0, str(backend_core_path))

import firebase_admin
from firebase_admin import credentials, firestore
from permissions_catalog import get_all_permissions


def seed_permissions_for_client(client_name: str):
    """
    Popula collection 'permissions' no Firestore do cliente

    Args:
        client_name: Nome do cliente (ex: 'clinica-medica')
    """
    # Caminho para credenciais do cliente
    credentials_path = backend_core_path.parent / "clientes" / client_name / "backend" / "secrets" / "firebase-admin-credentials.json"

    if not credentials_path.exists():
        print(f"❌ Erro: Credenciais não encontradas em {credentials_path}")
        print(f"   Certifique-se que o arquivo existe antes de executar o seed.")
        sys.exit(1)

    print(f"📁 Usando credenciais: {credentials_path}")

    # Inicializar Firebase
    try:
        cred = credentials.Certificate(str(credentials_path))
        app = firebase_admin.initialize_app(cred, name=f'seed-{client_name}')
        db = firestore.client(app=app)
        print(f"✅ Conectado ao Firebase do cliente: {client_name}")
    except Exception as e:
        print(f"❌ Erro ao conectar ao Firebase: {e}")
        sys.exit(1)

    # Buscar todas as permissões do catálogo
    permissions = get_all_permissions()
    print(f"\n📋 Total de permissões a serem criadas: {len(permissions)}")

    # Popular no Firestore
    created_count = 0
    updated_count = 0
    error_count = 0

    for perm in permissions:
        perm_id = perm["id"]

        try:
            # Verificar se já existe
            perm_ref = db.collection("permissions").document(perm_id)
            perm_doc = perm_ref.get()

            if perm_doc.exists:
                # Atualizar permissão existente
                perm_ref.set(perm)
                updated_count += 1
                print(f"  🔄 Atualizado: {perm_id}")
            else:
                # Criar nova permissão
                perm_ref.set(perm)
                created_count += 1
                print(f"  ✅ Criado: {perm_id}")

        except Exception as e:
            error_count += 1
            print(f"  ❌ Erro ao processar {perm_id}: {e}")

    # Resumo
    print(f"\n{'='*60}")
    print(f"📊 RESUMO DO SEED - Cliente: {client_name}")
    print(f"{'='*60}")
    print(f"✅ Permissões criadas:    {created_count}")
    print(f"🔄 Permissões atualizadas: {updated_count}")
    print(f"❌ Erros:                  {error_count}")
    print(f"{'='*60}")

    if error_count == 0:
        print(f"\n🎉 Seed concluído com sucesso!")
        print(f"   Collection 'permissions' populada com {len(permissions)} permissões.")
    else:
        print(f"\n⚠️  Seed concluído com {error_count} erros.")
        print(f"   Verifique os logs acima para detalhes.")

    # Cleanup
    firebase_admin.delete_app(app)


def main():
    """Função principal"""

    print(f"""
╔════════════════════════════════════════════════════════════════╗
║  SEED DE PERMISSÕES - SISTEMA RBAC GENÉRICO                   ║
║  Popula collection 'permissions' com 40 permissões genéricas   ║
╚════════════════════════════════════════════════════════════════╝
    """)

    # Validar argumentos
    if len(sys.argv) != 2:
        print("❌ Uso incorreto!")
        print("\nUso correto:")
        print("  python seed_permissions.py <nome-cliente>")
        print("\nExemplo:")
        print("  python seed_permissions.py clinica-medica")
        print("  python seed_permissions.py clinica-vet")
        sys.exit(1)

    client_name = sys.argv[1]

    # Confirmar antes de executar
    print(f"\n⚠️  Você está prestes a popular/atualizar as permissões para:")
    print(f"   Cliente: {client_name}")
    print(f"\n   Isso irá criar/atualizar a collection 'permissions' no Firestore.")

    confirm = input(f"\n   Deseja continuar? (sim/não): ").strip().lower()

    if confirm not in ['sim', 's', 'yes', 'y']:
        print("\n❌ Operação cancelada pelo usuário.")
        sys.exit(0)

    # Executar seed
    print(f"\n🚀 Iniciando seed de permissões...\n")
    seed_permissions_for_client(client_name)


if __name__ == "__main__":
    main()
