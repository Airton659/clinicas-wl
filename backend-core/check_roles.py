#!/usr/bin/env python3
import sys
import firebase_admin
from firebase_admin import credentials, firestore

def check_roles(cred_file, negocio_id):
    try:
        cred = credentials.Certificate(cred_file)
        app = firebase_admin.initialize_app(cred)
        db = firestore.client(app=app)

        print("🔍 Verificando perfis no banco...\n")

        roles_ref = db.collection("roles")
        query = roles_ref.where("negocio_id", "==", negocio_id).stream()

        print("📋 PERFIS ENCONTRADOS:")
        print("="*60)
        
        for doc in query:
            data = doc.to_dict()
            print(f"ID: {doc.id}")
            print(f"  Tipo: {data.get('tipo')}")
            print(f"  Nome: {data.get('nome_customizado')}")
            print(f"  Is System: {data.get('is_system')}")
            print("-"*60)

        firebase_admin.delete_app(app)

    except Exception as e:
        print(f"❌ Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Uso: python3 check_roles.py <credentials_file> <negocio_id>")
        sys.exit(1)

    check_roles(sys.argv[1], sys.argv[2])
