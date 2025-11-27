#!/usr/bin/env python3
"""
Script para:
1. Marcar Admin como sistema (is_system: true)
2. Deletar todos os usuários exceto o admin
"""
import sys
import firebase_admin
from firebase_admin import credentials, firestore

def fix_admin_and_cleanup(cred_file, negocio_id):
    """Corrige admin e limpa usuários"""
    try:
        # Inicializar Firebase
        cred = credentials.Certificate(cred_file)
        app = firebase_admin.initialize_app(cred)
        db = firestore.client(app=app)

        print("🔧 Corrigindo Admin e limpando usuários...\n")

        # 1. Corrigir Admin
        print("1️⃣  Corrigindo perfil Admin...")
        roles_ref = db.collection("roles")
        admin_query = roles_ref.where("negocio_id", "==", negocio_id).where("tipo", "==", "admin").stream()

        for doc in admin_query:
            doc.reference.update({
                'is_system': True,
                'updated_at': firestore.SERVER_TIMESTAMP
            })
            print(f"  ✅ Admin marcado como sistema (is_system: true)")

        # 2. Deletar todos os usuários exceto admin e super admin
        print("\n2️⃣  Deletando usuários (exceto admin e super admin)...")
        users_ref = db.collection("users")
        all_users = users_ref.stream()

        deleted = 0
        kept = 0

        for user_doc in all_users:
            user_data = user_doc.to_dict()
            roles = user_data.get('roles', {})
            user_role = roles.get(negocio_id, '')
            is_super_admin = user_data.get('is_super_admin', False)
            email = user_data.get('email', 'sem email')

            # Manter admin do negócio OU super admin
            if user_role == 'admin' or is_super_admin:
                tipo = 'super admin' if is_super_admin else 'admin'
                print(f"  ✅ Mantido: {email} ({tipo})")
                kept += 1
            else:
                user_doc.reference.delete()
                print(f"  🗑️  Deletado: {email} (role: {user_role})")
                deleted += 1

        print(f"\n{'='*60}")
        print(f"📊 RESUMO:")
        print(f"{'='*60}")
        print(f"✅ Admin configurado como sistema")
        print(f"👥 Usuários mantidos: {kept}")
        print(f"🗑️  Usuários deletados: {deleted}")
        print(f"{'='*60}")
        print(f"\n✅ Limpeza concluída!")

        firebase_admin.delete_app(app)

    except Exception as e:
        print(f"❌ Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Uso: python3 fix_admin_and_cleanup.py <credentials_file> <negocio_id>")
        sys.exit(1)

    fix_admin_and_cleanup(sys.argv[1], sys.argv[2])
