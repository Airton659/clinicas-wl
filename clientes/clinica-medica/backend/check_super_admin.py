#!/usr/bin/env python3
import sys
import firebase_admin
from firebase_admin import credentials, firestore

def check_super_admin(cred_file, email):
    try:
        cred = credentials.Certificate(cred_file)
        app = firebase_admin.initialize_app(cred)
        db = firestore.client(app=app)

        print(f"🔍 Procurando usuário: {email}\n")

        # Procurar em AMBAS as coleções
        for collection_name in ['usuarios', 'users']:
            print(f"🔍 Buscando na coleção '{collection_name}'...")
            users_ref = db.collection(collection_name)
            query = users_ref.where("email", "==", email).stream()

            found = False
            for doc in query:
                found = True
                data = doc.to_dict()
                print(f"  📄 Documento ID: {doc.id}")
                print(f"  📧 Email: {data.get('email')}")
                print(f"  👤 Nome: {data.get('nome')}")
                print(f"  🔑 is_super_admin: {data.get('is_super_admin', False)}")
                print(f"  📋 roles: {data.get('roles', {})}")
                print(f"  {'='*60}")

            if not found:
                print(f"  ⚠️  Não encontrado em '{collection_name}'\n")

        firebase_admin.delete_app(app)

    except Exception as e:
        print(f"❌ Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Uso: python3 check_super_admin.py <credentials_file> <email>")
        sys.exit(1)
    
    check_super_admin(sys.argv[1], sys.argv[2])
