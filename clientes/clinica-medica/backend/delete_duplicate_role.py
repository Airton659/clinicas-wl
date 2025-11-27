#!/usr/bin/env python3
"""
Script para deletar um perfil específico pelo ID
"""
import sys
import firebase_admin
from firebase_admin import credentials, firestore

def delete_role(cred_file, role_id):
    try:
        cred = credentials.Certificate(cred_file)
        app = firebase_admin.initialize_app(cred)
        db = firestore.client(app=app)

        print(f"🗑️  Deletando perfil ID: {role_id}...\n")

        roles_ref = db.collection("roles")
        doc = roles_ref.document(role_id).get()

        if not doc.exists:
            print(f"❌ Perfil {role_id} não encontrado!")
            return

        data = doc.to_dict()
        print(f"📋 Perfil encontrado:")
        print(f"  Tipo: {data.get('tipo')}")
        print(f"  Nome: {data.get('nome_customizado')}")
        print(f"  Is System: {data.get('is_system')}")
        print()

        # Deletar
        roles_ref.document(role_id).delete()
        print(f"✅ Perfil deletado com sucesso!")

        firebase_admin.delete_app(app)

    except Exception as e:
        print(f"❌ Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Uso: python3 delete_duplicate_role.py <credentials_file> <role_id>")
        sys.exit(1)

    delete_role(sys.argv[1], sys.argv[2])
