#!/usr/bin/env python3
"""
Script para criar perfis padrão do sistema (Admin, Profissional, Técnico)
"""
import sys
import firebase_admin
from firebase_admin import credentials, firestore

DEFAULT_ROLES = [
    {
        "id": "admin",
        "nome_customizado": "Admin",
        "descricao_customizada": "Administrador com acesso total ao sistema",
        "tipo": "admin",
        "nivel_hierarquico": 100,
        "cor": "#1976D2",
        "icone": "admin_panel_settings",
        "permissions": [
            # Pacientes - TODAS
            "patients.create", "patients.read", "patients.update", "patients.delete", "patients.link_team",
            # Plano de Cuidados - TODAS
            "consultations.create", "consultations.read", "consultations.update", "consultations.delete",
            # Anamnese - TODAS
            "anamnese.create", "anamnese.read", "anamnese.update",
            # Exames - TODAS
            "exams.create", "exams.read", "exams.update", "exams.delete",
            # Medicações - TODAS
            "medications.create", "medications.read", "medications.update", "medications.delete",
            # Checklist - TODAS
            "checklist.create", "checklist.read", "checklist.update",
            # Orientações - TODAS
            "guidelines.create", "guidelines.read", "guidelines.update",
            # Diário - TODAS
            "diary.create", "diary.read", "diary.update",
            # Relatórios Médicos - TODAS
            "medical_reports.create", "medical_reports.read", "medical_reports.update",
            # Equipe - TODAS
            "team.read", "team.invite", "team.update_role", "team.update_status",
            # Dashboard - TODAS
            "dashboard.view_own", "dashboard.view_team",
            # Configurações - TODAS (INCLUINDO GERENCIAR PERMISSÕES!)
            "settings.manage_business", "settings.manage_permissions",
        ]
    },
    {
        "id": "profissional",
        "nome_customizado": "Profissional",
        "descricao_customizada": "Profissional com acesso clínico completo",
        "tipo": "professional",
        "nivel_hierarquico": 50,
        "cor": "#388E3C",
        "icone": "medical_services",
        "permissions": [
            # Pacientes - CRUD completo
            "patients.create", "patients.read", "patients.update", "patients.delete", "patients.link_team",
            # Plano de Cuidados - CRUD completo
            "consultations.create", "consultations.read", "consultations.update", "consultations.delete",
            # Anamnese - completo
            "anamnese.create", "anamnese.read", "anamnese.update",
            # Exames - completo
            "exams.create", "exams.read", "exams.update", "exams.delete",
            # Medicações - completo
            "medications.create", "medications.read", "medications.update", "medications.delete",
            # Checklist - completo
            "checklist.create", "checklist.read", "checklist.update",
            # Orientações - completo
            "guidelines.create", "guidelines.read", "guidelines.update",
            # Diário - completo
            "diary.create", "diary.read", "diary.update",
            # Relatórios Médicos - completo
            "medical_reports.create", "medical_reports.read", "medical_reports.update",
            # Equipe - apenas visualização
            "team.read",
            # Dashboard - próprio
            "dashboard.view_own",
        ]
    },
    {
        "id": "tecnico",
        "nome_customizado": "Técnico",
        "descricao_customizada": "Técnico com acesso operacional",
        "tipo": "technician",
        "nivel_hierarquico": 25,
        "cor": "#FF9800",
        "icone": "support_agent",
        "permissions": [
            # Pacientes - apenas leitura e criação
            "patients.create", "patients.read",
            # Plano de Cuidados - leitura
            "consultations.read",
            # Anamnese - leitura
            "anamnese.read",
            # Exames - leitura
            "exams.read",
            # Medicações - leitura
            "medications.read",
            # Checklist - completo (técnico gerencia checklist)
            "checklist.create", "checklist.read", "checklist.update",
            # Orientações - leitura
            "guidelines.read",
            # Diário - completo (técnico escreve no diário)
            "diary.create", "diary.read", "diary.update",
            # Relatórios Médicos - leitura apenas
            "medical_reports.read",
            # Equipe - leitura
            "team.read",
            # Dashboard - próprio
            "dashboard.view_own",
        ]
    },
]


def seed_default_roles(cred_file, negocio_id):
    """Cria perfis padrão no Firestore"""
    try:
        # Inicializar Firebase
        cred = credentials.Certificate(cred_file)
        app = firebase_admin.initialize_app(cred)
        db = firestore.client(app=app)

        print("🎭 Criando perfis padrão...\n")

        # CORREÇÃO: Usar coleção 'roles' com campo negocio_id ao invés de subcoleção
        roles_ref = db.collection("roles")

        created = 0
        updated = 0

        for role in DEFAULT_ROLES:
            # Adicionar negocio_id e campos obrigatórios
            role_data = {
                **role,
                "negocio_id": negocio_id,
                "is_system": False,  # Todos os perfis podem ser editados
                "is_active": True,
                "created_at": firestore.SERVER_TIMESTAMP,
                "updated_at": firestore.SERVER_TIMESTAMP,
            }

            # Buscar role existente por negocio_id + tipo
            existing_query = roles_ref.where("negocio_id", "==", negocio_id)\
                .where("tipo", "==", role["tipo"])\
                .limit(1).stream()

            existing_doc = None
            for doc in existing_query:
                existing_doc = doc
                break

            if existing_doc:
                # Atualizar existente
                existing_doc.reference.set(role_data)
                updated += 1
                print(f"  🔄 Atualizado: {role['nome_customizado']} ({len(role['permissions'])} permissões)")
            else:
                # Criar novo
                roles_ref.add(role_data)
                created += 1
                print(f"  ✅ Criado: {role['nome_customizado']} ({len(role['permissions'])} permissões)")

        print(f"\n{'='*60}")
        print(f"📊 RESUMO:")
        print(f"{'='*60}")
        print(f"✅ Criados:     {created}")
        print(f"🔄 Atualizados: {updated}")
        print(f"{'='*60}")
        print(f"\n🎉 Perfis padrão configurados com sucesso!")

        # Mostrar permissões do Admin
        admin_perms = DEFAULT_ROLES[0]["permissions"]
        config_perms = [p for p in admin_perms if p.startswith("settings.")]
        print(f"\n🔧 Permissões de Configurações do Admin ({len(config_perms)}):")
        for perm in config_perms:
            print(f"   ✓ {perm}")

        firebase_admin.delete_app(app)

    except Exception as e:
        print(f"❌ Erro: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Uso: python3 seed_default_roles.py <credentials_file> <negocio_id>")
        sys.exit(1)

    seed_default_roles(sys.argv[1], sys.argv[2])
