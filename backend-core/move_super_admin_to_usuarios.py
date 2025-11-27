#!/usr/bin/env python3
import sys
import firebase_admin
from firebase_admin import credentials, firestore

def move_super_admin(cred_file, email):
    try:
        cred = credentials.Certificate(cred_file)
        app = firebase_admin.initialize_app(cred)
        db = firestore.client(app=app)

        print(f"🔍 Procurando super admin: {email}\n")
        
        # 1. Buscar na coleção "users"
        users_ref = db.collection("users")
        query = users_ref.where("email", "==", email).stream()

        user_data = None
        old_doc_id = None
        for doc in query:
            old_doc_id = doc.id
            user_data = doc.to_dict()
            print(f"✅ Encontrado na coleção 'users' (ID: {old_doc_id})")
            break

        if not user_data:
            print(f"❌ Usuário não encontrado na coleção 'users'")
            firebase_admin.delete_app(app)
            sys.exit(1)

        # 2. Criar na coleção "usuarios" mantendo o mesmo UID
        usuarios_ref = db.collection("usuarios")
        
        # Usar o firebase_uid como ID do documento
        firebase_uid = user_data.get('firebase_uid') or old_doc_id
        
        print(f"📝 Criando na coleção 'usuarios' com UID: {firebase_uid}")
        
        # Garantir que tem is_super_admin
        user_data['is_super_admin'] = True
        user_data['updated_at'] = firestore.SERVER_TIMESTAMP
        
        # Criar documento na coleção usuarios
        usuarios_ref.document(firebase_uid).set(user_data)
        
        print(f"✅ Documento criado na coleção 'usuarios'")
        
        # 3. Deletar da coleção "users"
        users_ref.document(old_doc_id).delete()
        print(f"🗑️  Documento removido da coleção 'users'")
        
        print(f"\n{'='*60}")
        print(f"✅ SUPER ADMIN MOVIDO COM SUCESSO!")
        print(f"{'='*60}")
        print(f"📧 Email: {email}")
        print(f"👤 UID: {firebase_uid}")
        print(f"🔒 is_super_admin: True")
        print(f"{'='*60}")

        firebase_admin.delete_app(app)

    except Exception as e:
        print(f"❌ Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Uso: python3 move_super_admin_to_usuarios.py <credentials_file> <email>")
        sys.exit(1)
    
    move_super_admin(sys.argv[1], sys.argv[2])
