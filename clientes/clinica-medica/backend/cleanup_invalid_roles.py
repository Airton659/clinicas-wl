#!/usr/bin/env python3
"""
Script para limpar roles inválidos (sem nome e tipo)
"""
import sys
import firebase_admin
from firebase_admin import credentials, firestore

def cleanup_invalid_roles(cred_file, negocio_id):
    """Deleta roles sem nome ou tipo definido"""
    try:
        # Inicializar Firebase
        cred = credentials.Certificate(cred_file)
        app = firebase_admin.initialize_app(cred)
        db = firestore.client(app=app)

        print("🧹 Limpando roles inválidos...\n")

        roles_ref = db.collection("roles")
        query = roles_ref.where("negocio_id", "==", negocio_id).stream()

        deleted = 0

        for doc in query:
            role_data = doc.to_dict()
            nome = role_data.get('nome_customizado', '')
            tipo = role_data.get('tipo', '')

            # Deletar se não tem nome ou tipo válido
            if nome == 'Sem Nome' or nome == '' or tipo == 'custom' or tipo == '':
                doc.reference.delete()
                deleted += 1
                print(f"  🗑️  Deletado: {role_data.get('nome_customizado', 'Sem nome')} (tipo: {role_data.get('tipo', 'sem tipo')}, id: {doc.id})")
            else:
                print(f"  ✅ Válido: {nome} ({tipo})")

        print(f"\n{'='*60}")
        print(f"📊 RESUMO:")
        print(f"{'='*60}")
        print(f"🗑️  Deletados: {deleted}")
        print(f"{'='*60}")
        print(f"\n✅ Limpeza concluída!")

        firebase_admin.delete_app(app)

    except Exception as e:
        print(f"❌ Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Uso: python3 cleanup_invalid_roles.py <credentials_file> <negocio_id>")
        sys.exit(1)

    cleanup_invalid_roles(sys.argv[1], sys.argv[2])
