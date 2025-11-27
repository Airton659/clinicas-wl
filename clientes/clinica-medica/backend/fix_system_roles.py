#!/usr/bin/env python3
"""
Script para marcar todos os roles como is_system: False
"""
import sys
import firebase_admin
from firebase_admin import credentials, firestore

def fix_system_roles(cred_file, negocio_id):
    """Marca todos os roles como editáveis (is_system: False)"""
    try:
        # Inicializar Firebase
        cred = credentials.Certificate(cred_file)
        app = firebase_admin.initialize_app(cred)
        db = firestore.client(app=app)

        print("🔧 Corrigindo flags is_system...\n")

        roles_ref = db.collection("roles")
        query = roles_ref.where("negocio_id", "==", negocio_id).stream()

        updated = 0

        for doc in query:
            role_data = doc.to_dict()
            current_is_system = role_data.get('is_system', False)

            # Se está marcado como sistema, corrigir
            if current_is_system:
                doc.reference.update({
                    'is_system': False,
                    'updated_at': firestore.SERVER_TIMESTAMP
                })
                updated += 1
                print(f"  ✅ Corrigido: {role_data.get('nome_customizado', 'Sem nome')} ({role_data.get('tipo', 'sem tipo')})")
            else:
                print(f"  ℹ️  Já OK: {role_data.get('nome_customizado', 'Sem nome')} ({role_data.get('tipo', 'sem tipo')})")

        print(f"\n{'='*60}")
        print(f"📊 RESUMO:")
        print(f"{'='*60}")
        print(f"✅ Atualizados: {updated}")
        print(f"{'='*60}")
        print(f"\n✅ Todos os perfis agora são editáveis!")

        firebase_admin.delete_app(app)

    except Exception as e:
        print(f"❌ Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Uso: python3 fix_system_roles.py <credentials_file> <negocio_id>")
        sys.exit(1)

    fix_system_roles(sys.argv[1], sys.argv[2])
