#!/usr/bin/env python3
import sys
import firebase_admin
from firebase_admin import credentials, firestore

def delete_user(cred_file, doc_id):
    try:
        cred = credentials.Certificate(cred_file)
        app = firebase_admin.initialize_app(cred)
        db = firestore.client(app=app)

        print(f"🗑️  Deletando documento: {doc_id}\n")
        
        doc_ref = db.collection("usuarios").document(doc_id)
        doc = doc_ref.get()
        
        if doc.exists:
            data = doc.to_dict()
            print(f"📄 Email: {data.get('email')}")
            print(f"🔑 is_super_admin: {data.get('is_super_admin', False)}")
            print(f"📋 roles: {data.get('roles', {})}")
            
            doc_ref.delete()
            print(f"\n✅ Documento deletado com sucesso!")
        else:
            print(f"❌ Documento não encontrado!")

        firebase_admin.delete_app(app)

    except Exception as e:
        print(f"❌ Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Uso: python3 delete_duplicate_user.py <credentials_file> <doc_id>")
        sys.exit(1)
    
    delete_user(sys.argv[1], sys.argv[2])
