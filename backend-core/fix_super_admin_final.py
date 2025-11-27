#!/usr/bin/env python3
import sys
import firebase_admin
from firebase_admin import credentials, firestore

def fix_super_admin(cred_file, email):
    try:
        cred = credentials.Certificate(cred_file)
        app = firebase_admin.initialize_app(cred)
        db = firestore.client(app=app)

        print(f"🔧 Corrigindo Super Admin: {email}\n")
        
        # 1. Buscar e DELETAR documento existente em TODAS as coleções
        for collection_name in ['users', 'usuarios']:
            print(f"🔍 Verificando coleção '{collection_name}'...")
            query = db.collection(collection_name).where("email", "==", email).stream()
            
            for doc in query:
                print(f"  🗑️  Deletando documento ID: {doc.id}")
                doc.reference.delete()
        
        # 2. Criar documento LIMPO na coleção usuarios
        print(f"\n📝 Criando novo documento na coleção 'usuarios'...")
        
        # Buscar o UID do Firebase Auth
        from firebase_admin import auth
        try:
            firebase_user = auth.get_user_by_email(email)
            uid = firebase_user.uid
            print(f"  ✅ UID do Firebase Auth: {uid}")
        except:
            print(f"  ❌ Usuário não existe no Firebase Auth!")
            firebase_admin.delete_app(app)
            sys.exit(1)
        
        # Criar documento APENAS com is_super_admin, sem roles de negócio
        usuarios_ref = db.collection("usuarios")
        usuarios_ref.document(uid).set({
            'email': email,
            'is_super_admin': True,
            'roles': {'platform': 'platform'},  # SEM role de negócio!
            'created_at': firestore.SERVER_TIMESTAMP,
            'updated_at': firestore.SERVER_TIMESTAMP
        })
        
        print(f"  ✅ Documento criado com sucesso!")
        
        print(f"\n{'='*60}")
        print(f"✅ SUPER ADMIN CONFIGURADO!")
        print(f"{'='*60}")
        print(f"📧 Email: {email}")
        print(f"👤 UID: {uid}")
        print(f"🔒 is_super_admin: True")
        print(f"📋 roles: {{'platform': 'platform'}}")
        print(f"{'='*60}")
        print(f"\n⚠️  IMPORTANTE: FAÇA LOGOUT E LOGIN NOVAMENTE!")
        print(f"{'='*60}")

        firebase_admin.delete_app(app)

    except Exception as e:
        print(f"❌ Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Uso: python3 fix_super_admin_final.py <credentials_file> <email>")
        sys.exit(1)
    
    fix_super_admin(sys.argv[1], sys.argv[2])
