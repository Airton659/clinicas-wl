#!/usr/bin/env python3
"""
Script para criar usuário Super Admin (role="platform")
"""
import sys
import firebase_admin
from firebase_admin import credentials, auth, firestore

def create_super_admin(cred_file, email, password, nome):
    """Cria usuário Super Admin com role=platform"""
    try:
        # Inicializar Firebase
        cred = credentials.Certificate(cred_file)
        app = firebase_admin.initialize_app(cred)
        db = firestore.client(app=app)

        print("🦸 Criando Super Admin...\n")

        # 1. Criar usuário no Firebase Auth
        try:
            user = auth.create_user(
                email=email,
                password=password,
                display_name=nome,
                email_verified=True,
                app=app
            )
            print(f"✅ Usuário criado no Firebase Auth")
            print(f"   UID: {user.uid}")
            print(f"   Email: {user.email}")
        except auth.EmailAlreadyExistsError:
            print(f"⚠️  Email já existe, buscando usuário...")
            user = auth.get_user_by_email(email, app=app)
            print(f"   UID encontrado: {user.uid}")

        # 2. Criar documento no Firestore com role="platform"
        user_data = {
            "firebase_uid": user.uid,
            "email": email,
            "nome": nome,
            "roles": {
                "platform": "platform"  # Super Admin role
            },
            "consentimento_lgpd": True,
            "tipo_consentimento": "digital",
            "data_consentimento_lgpd": firestore.SERVER_TIMESTAMP,
        }

        usuarios_ref = db.collection("usuarios")

        # Verificar se já existe documento com este email
        existing_docs = usuarios_ref.where("email", "==", email).limit(1).stream()

        doc_id = None
        for doc in existing_docs:
            doc_id = doc.id
            break

        if doc_id:
            # Atualizar documento existente
            usuarios_ref.document(doc_id).set(user_data, merge=True)
            print(f"\n✅ Documento atualizado no Firestore")
            print(f"   Doc ID: {doc_id}")
        else:
            # Criar novo documento
            doc_ref = usuarios_ref.add(user_data)
            doc_id = doc_ref[1].id
            print(f"\n✅ Documento criado no Firestore")
            print(f"   Doc ID: {doc_id}")

        # 3. Verificar o role
        doc = usuarios_ref.document(doc_id).get()
        roles = doc.to_dict().get("roles", {})

        print(f"\n{'='*60}")
        print(f"🦸 SUPER ADMIN CRIADO COM SUCESSO!")
        print(f"{'='*60}")
        print(f"Email:    {email}")
        print(f"Nome:     {nome}")
        print(f"UID:      {user.uid}")
        print(f"Doc ID:   {doc_id}")
        print(f"Roles:    {roles}")
        print(f"{'='*60}")

        if "platform" in roles.values():
            print(f"✅ Role 'platform' confirmado - usuário é Super Admin!")
        else:
            print(f"⚠️  ATENÇÃO: Role 'platform' não encontrado!")

        print(f"\n📝 Credenciais de acesso:")
        print(f"   Email:    {email}")
        print(f"   Senha:    {password}")
        print(f"\n⚠️  IMPORTANTE: Guarde estas credenciais em local seguro!")

        firebase_admin.delete_app(app)

    except Exception as e:
        print(f"❌ Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Uso: python3 create_super_admin.py <credentials_file> <email> <password> <nome>")
        print('Exemplo: python3 create_super_admin.py cred.json "superadmin@example.com" "senha123" "Super Admin"')
        sys.exit(1)

    create_super_admin(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
