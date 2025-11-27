#!/usr/bin/env python3
import sys
import firebase_admin
from firebase_admin import credentials, firestore, auth

def set_super_admin(cred_file, email):
    try:
        cred = credentials.Certificate(cred_file)
        app = firebase_admin.initialize_app(cred)
        db = firestore.client(app=app)

        print(f"🔍 Procurando usuário: {email}\n")
        
        # Primeiro tenta achar no Firestore
        users_ref = db.collection("users")
        query = users_ref.where("email", "==", email).stream()

        doc_found = None
        for doc in query:
            doc_found = doc
            break

        if doc_found:
            # Usuário existe, vamos atualizar
            print(f"✅ Usuário encontrado no Firestore (ID: {doc_found.id})")
            doc_found.reference.update({
                'is_super_admin': True,
                'updated_at': firestore.SERVER_TIMESTAMP
            })
            print(f"✅ Campo is_super_admin atualizado para TRUE!")
        else:
            # Usuário não existe no Firestore, vamos criar
            print(f"⚠️  Usuário não encontrado no Firestore")
            
            # Procurar no Firebase Auth
            try:
                firebase_user = auth.get_user_by_email(email)
                print(f"✅ Usuário encontrado no Firebase Auth (UID: {firebase_user.uid})")
                
                # Criar documento no Firestore
                users_ref.document(firebase_user.uid).set({
                    'email': email,
                    'is_super_admin': True,
                    'roles': {'platform': 'platform'},
                    'created_at': firestore.SERVER_TIMESTAMP,
                    'updated_at': firestore.SERVER_TIMESTAMP
                })
                print(f"✅ Documento criado no Firestore com is_super_admin: true!")
                
            except auth.UserNotFoundError:
                print(f"❌ Usuário não existe nem no Firebase Auth!")
                print(f"💡 Crie o usuário primeiro no Firebase Console ou via script")
                firebase_admin.delete_app(app)
                sys.exit(1)

        print(f"\n{'='*60}")
        print(f"✅ CONCLUÍDO! Usuário {email} agora é Super Admin")
        print(f"{'='*60}")

        firebase_admin.delete_app(app)

    except Exception as e:
        print(f"❌ Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Uso: python3 set_super_admin.py <credentials_file> <email>")
        sys.exit(1)
    
    set_super_admin(sys.argv[1], sys.argv[2])
