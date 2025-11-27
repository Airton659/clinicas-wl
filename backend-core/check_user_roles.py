#!/usr/bin/env python3
"""
Script para verificar roles de um usuário
"""
import sys
import firebase_admin
from firebase_admin import credentials, firestore

def check_user_roles(cred_file, email, negocio_id):
    """Verifica roles de um usuário"""
    try:
        # Inicializar Firebase
        cred = credentials.Certificate(cred_file)
        app = firebase_admin.initialize_app(cred)
        db = firestore.client(app=app)

        print(f"🔍 Verificando usuário: {email}\n")

        # Buscar usuário por email
        usuarios_ref = db.collection("usuarios")
        user_query = usuarios_ref.where("email", "==", email).limit(1).stream()

        user_doc = None
        for doc in user_query:
            user_doc = doc
            break

        if not user_doc:
            print(f"❌ Usuário não encontrado: {email}")
            sys.exit(1)

        user_data = user_doc.to_dict()
        user_id = user_doc.id

        print(f"✅ Usuário encontrado!")
        print(f"   Doc ID: {user_id}")
        print(f"   Nome: {user_data.get('nome', 'N/A')}")
        print(f"   Email: {user_data.get('email')}")
        print(f"   Firebase UID: {user_data.get('firebase_uid')}")
        print(f"\n📋 Roles do usuário:")

        roles = user_data.get("roles", {})
        if not roles:
            print("   ⚠️  Nenhum role encontrado!")
        else:
            for key, value in roles.items():
                print(f"   • {key}: {value}")

        # Verificar role específico do negócio
        print(f"\n🏢 Role no negócio {negocio_id}:")
        negocio_role = roles.get(negocio_id)
        if negocio_role:
            print(f"   ✅ Role encontrado: {negocio_role}")

            # Buscar perfil correspondente
            role_ref = db.collection("negocios").document(negocio_id).collection("roles").document(negocio_role)
            role_doc = role_ref.get()

            if role_doc.exists:
                role_data = role_doc.to_dict()
                permissions = role_data.get("permissions", [])
                print(f"\n🎭 Detalhes do perfil '{negocio_role}':")
                print(f"   Nome: {role_data.get('nome')}")
                print(f"   Tipo: {role_data.get('type')}")
                print(f"   Total de permissões: {len(permissions)}")

                # Verificar permissão específica
                if "settings.manage_permissions" in permissions:
                    print(f"\n   ✅ TEM permissão 'settings.manage_permissions'")
                else:
                    print(f"\n   ❌ NÃO TEM permissão 'settings.manage_permissions'")

                # Mostrar todas as permissões de settings
                settings_perms = [p for p in permissions if p.startswith("settings.")]
                print(f"\n   Permissões de Configurações ({len(settings_perms)}):")
                for perm in settings_perms:
                    print(f"      • {perm}")
            else:
                print(f"   ⚠️  Perfil '{negocio_role}' não encontrado na coleção de roles!")
        else:
            print(f"   ❌ Nenhum role encontrado para este negócio")

        firebase_admin.delete_app(app)

    except Exception as e:
        print(f"❌ Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Uso: python3 check_user_roles.py <credentials_file> <email> <negocio_id>")
        print('Exemplo: python3 check_user_roles.py cred.json "admin@com.br" "UtFHQf3lwIHfMmf8wHDu"')
        sys.exit(1)

    check_user_roles(sys.argv[1], sys.argv[2], sys.argv[3])
