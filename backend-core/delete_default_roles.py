#!/usr/bin/env python3
"""
Script para deletar perfis padrão (Admin, Profissional, Técnico)
"""
import sys
import firebase_admin
from firebase_admin import credentials, firestore

def delete_default_roles(cred_file, negocio_id):
    """Deleta perfis padrão criados por engano"""
    try:
        # Inicializar Firebase
        cred = credentials.Certificate(cred_file)
        app = firebase_admin.initialize_app(cred)
        db = firestore.client(app=app)

        print("🗑️  Deletando perfis padrão...\n")

        roles_ref = db.collection("roles")

        # Buscar perfis do negócio com tipos específicos (NÃO deletar admin)
        tipos_para_deletar = ["professional", "technician", "medico"]

        deleted = 0

        for tipo in tipos_para_deletar:
            query = roles_ref.where("negocio_id", "==", negocio_id)\
                .where("tipo", "==", tipo)\
                .stream()

            for doc in query:
                role_data = doc.to_dict()
                doc.reference.delete()
                deleted += 1
                print(f"  🗑️  Deletado: {role_data.get('nome_customizado', 'Sem nome')} ({tipo})")

        print(f"\n{'='*60}")
        print(f"📊 RESUMO:")
        print(f"{'='*60}")
        print(f"🗑️  Deletados: {deleted}")
        print(f"{'='*60}")
        print(f"\n✅ Perfis padrão removidos com sucesso!")

        firebase_admin.delete_app(app)

    except Exception as e:
        print(f"❌ Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Uso: python3 delete_default_roles.py <credentials_file> <negocio_id>")
        sys.exit(1)

    delete_default_roles(sys.argv[1], sys.argv[2])
