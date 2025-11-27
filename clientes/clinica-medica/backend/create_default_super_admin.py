#!/usr/bin/env python3
"""
Script para criar o Super Admin padrão em um projeto Firebase
Email: whitetree.ia@gmail.com
"""
import sys
import firebase_admin
from firebase_admin import credentials, firestore, auth

def create_super_admin(cred_file):
    try:
        cred = credentials.Certificate(cred_file)
        app = firebase_admin.initialize_app(cred)
        db = firestore.client(app=app)

        super_admin_email = "whitetree.ia@gmail.com"
        super_admin_password = "WhiteTree2024!"  # Senha padrão
        
        print(f"🔧 Criando Super Admin padrão...")
        print(f"📧 Email: {super_admin_email}\n")

        # 1. Verificar se já existe no Firebase Auth
        try:
            firebase_user = auth.get_user_by_email(super_admin_email)
            print(f"✅ Usuário já existe no Firebase Auth (UID: {firebase_user.uid})")
            uid = firebase_user.uid
        except auth.UserNotFoundError:
            # Criar no Firebase Auth
            print(f"⚠️  Usuário não existe no Firebase Auth, criando...")
            firebase_user = auth.create_user(
                email=super_admin_email,
                password=super_admin_password,
                email_verified=True
            )
            uid = firebase_user.uid
            print(f"✅ Usuário criado no Firebase Auth (UID: {uid})")
            print(f"🔑 Senha: {super_admin_password}")

        # 2. Verificar se já existe no Firestore
        users_ref = db.collection("users")
        doc = users_ref.document(uid).get()

        if doc.exists:
            # Atualizar para garantir que tem is_super_admin
            data = doc.to_dict()
            if data.get('is_super_admin') == True:
                print(f"✅ Documento já existe no Firestore e já é Super Admin")
            else:
                users_ref.document(uid).update({
                    'is_super_admin': True,
                    'updated_at': firestore.SERVER_TIMESTAMP
                })
                print(f"✅ Documento atualizado no Firestore com is_super_admin: true")
        else:
            # Criar documento no Firestore
            users_ref.document(uid).set({
                'email': super_admin_email,
                'nome': 'Super Admin',
                'is_super_admin': True,
                'roles': {'platform': 'platform'},
                'created_at': firestore.SERVER_TIMESTAMP,
                'updated_at': firestore.SERVER_TIMESTAMP
            })
            print(f"✅ Documento criado no Firestore com is_super_admin: true")

        print(f"\n{'='*60}")
        print(f"✅ SUPER ADMIN CONFIGURADO COM SUCESSO!")
        print(f"{'='*60}")
        print(f"📧 Email: {super_admin_email}")
        print(f"🔑 Senha: {super_admin_password}")
        print(f"👤 UID: {uid}")
        print(f"{'='*60}")

        firebase_admin.delete_app(app)

    except Exception as e:
        print(f"❌ Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Uso: python3 create_default_super_admin.py <credentials_file>")
        sys.exit(1)
    
    create_super_admin(sys.argv[1])
