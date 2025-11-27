#!/usr/bin/env python3
"""
Script para adicionar permissão settings.manage_permissions ao perfil Admin
"""
import sys
import os
import firebase_admin
from firebase_admin import credentials, firestore

def fix_admin_permissions(cred_file, negocio_id):
    """Adiciona permissão de gerenciar permissões ao perfil Admin"""
    try:
        # Inicializar Firebase
        cred = credentials.Certificate(cred_file)
        app = firebase_admin.initialize_app(cred)
        db = firestore.client(app=app)

        print("🔧 Corrigindo permissões do perfil Admin...\n")

        # Buscar perfil Admin
        roles_ref = db.collection("negocios").document(negocio_id).collection("roles")
        admin_query = roles_ref.where("type", "==", "admin").limit(1).stream()

        admin_role = None
        for doc in admin_query:
            admin_role = doc
            break

        if not admin_role:
            print("❌ Perfil Admin não encontrado!")
            sys.exit(1)

        admin_data = admin_role.to_dict()
        current_permissions = admin_data.get("permissions", [])

        print(f"📋 Perfil encontrado: {admin_role.id}")
        print(f"   Nome: {admin_data.get('nome')}")
        print(f"   Permissões atuais: {len(current_permissions)}")

        # Verificar se já tem a permissão
        if "settings.manage_permissions" in current_permissions:
            print("\n✅ Permissão 'settings.manage_permissions' já existe!")
        else:
            # Adicionar permissão
            current_permissions.append("settings.manage_permissions")
            admin_role.reference.update({
                "permissions": current_permissions
            })
            print(f"\n✅ Permissão 'settings.manage_permissions' adicionada!")
            print(f"   Total de permissões agora: {len(current_permissions)}")

        # Mostrar todas as permissões de configurações
        config_perms = [p for p in current_permissions if p.startswith("settings.")]
        print(f"\n🔧 Permissões de Configurações ({len(config_perms)}):")
        for perm in config_perms:
            print(f"   ✓ {perm}")

        firebase_admin.delete_app(app)
        print("\n🎉 Correção concluída com sucesso!")

    except Exception as e:
        print(f"❌ Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Uso: python3 fix_admin_permissions.py <credentials_file> <negocio_id>")
        sys.exit(1)

    fix_admin_permissions(sys.argv[1], sys.argv[2])
