"""
Catálogo de Permissões do Sistema - GENÉRICO E REPLICÁVEL

IMPORTANTE: Todas as permissões usam nomes GENÉRICOS que funcionam para:
- Clínica Médica: "patients" = Pacientes
- Veterinária: "patients" = Animais (pets)
- Fisioterapia: "patients" = Pacientes
- Psicologia: "patients" = Pacientes
- etc.

O admin de cada empresa customiza a TERMINOLOGIA (Patient → Animal)
mas o código sempre usa os mesmos IDs genéricos.
"""

PERMISSIONS_CATALOG = [
    # ===== GESTÃO DE PACIENTES (5 permissões) =====
    {
        "id": "patients.create",
        "categoria": "Pacientes",
        "nome": "Criar Paciente",
        "descricao": "Permite criar novos pacientes no sistema",
        "recurso": "patients",
        "acao": "create"
    },
    {
        "id": "patients.read",
        "categoria": "Pacientes",
        "nome": "Ver Pacientes",
        "descricao": "Permite visualizar lista e detalhes de pacientes",
        "recurso": "patients",
        "acao": "read"
    },
    {
        "id": "patients.update",
        "categoria": "Pacientes",
        "nome": "Editar Paciente",
        "descricao": "Permite editar dados de pacientes",
        "recurso": "patients",
        "acao": "update"
    },
    {
        "id": "patients.delete",
        "categoria": "Pacientes",
        "nome": "Excluir Paciente",
        "descricao": "Permite excluir pacientes do sistema",
        "recurso": "patients",
        "acao": "delete"
    },
    {
        "id": "patients.link_team",
        "categoria": "Pacientes",
        "nome": "Vincular Equipe",
        "descricao": "Permite vincular profissionais ao paciente",
        "recurso": "patients",
        "acao": "link_team"
    },

    # ===== PLANO DE CUIDADOS / CONSULTAS (4 permissões) =====
    {
        "id": "consultations.create",
        "categoria": "Plano de Cuidados",
        "nome": "Criar Plano de Cuidados",
        "descricao": "Permite criar novos planos de cuidados/consultas",
        "recurso": "consultations",
        "acao": "create"
    },
    {
        "id": "consultations.read",
        "categoria": "Plano de Cuidados",
        "nome": "Ver Planos",
        "descricao": "Permite visualizar planos de cuidados/consultas",
        "recurso": "consultations",
        "acao": "read"
    },
    {
        "id": "consultations.update",
        "categoria": "Plano de Cuidados",
        "nome": "Editar Plano",
        "descricao": "Permite editar planos de cuidados/consultas",
        "recurso": "consultations",
        "acao": "update"
    },
    {
        "id": "consultations.delete",
        "categoria": "Plano de Cuidados",
        "nome": "Excluir Plano",
        "descricao": "Permite excluir planos de cuidados/consultas",
        "recurso": "consultations",
        "acao": "delete"
    },

    # ===== ANAMNESE (3 permissões) =====
    {
        "id": "anamnese.create",
        "categoria": "Anamnese",
        "nome": "Criar Anamnese",
        "descricao": "Permite criar anamnese para pacientes",
        "recurso": "anamnese",
        "acao": "create"
    },
    {
        "id": "anamnese.read",
        "categoria": "Anamnese",
        "nome": "Ver Anamnese",
        "descricao": "Permite visualizar anamnese de pacientes",
        "recurso": "anamnese",
        "acao": "read"
    },
    {
        "id": "anamnese.update",
        "categoria": "Anamnese",
        "nome": "Editar Anamnese",
        "descricao": "Permite editar anamnese de pacientes",
        "recurso": "anamnese",
        "acao": "update"
    },

    # ===== EXAMES (4 permissões) =====
    {
        "id": "exams.create",
        "categoria": "Exames",
        "nome": "Cadastrar Exame",
        "descricao": "Permite cadastrar exames para pacientes",
        "recurso": "exams",
        "acao": "create"
    },
    {
        "id": "exams.read",
        "categoria": "Exames",
        "nome": "Ver Exames",
        "descricao": "Permite visualizar exames de pacientes",
        "recurso": "exams",
        "acao": "read"
    },
    {
        "id": "exams.update",
        "categoria": "Exames",
        "nome": "Editar Exame",
        "descricao": "Permite editar exames cadastrados",
        "recurso": "exams",
        "acao": "update"
    },
    {
        "id": "exams.delete",
        "categoria": "Exames",
        "nome": "Excluir Exame",
        "descricao": "Permite excluir exames cadastrados",
        "recurso": "exams",
        "acao": "delete"
    },

    # ===== MEDICAÇÕES (4 permissões) =====
    {
        "id": "medications.create",
        "categoria": "Medicações",
        "nome": "Cadastrar Medicação",
        "descricao": "Permite cadastrar medicações para pacientes",
        "recurso": "medications",
        "acao": "create"
    },
    {
        "id": "medications.read",
        "categoria": "Medicações",
        "nome": "Ver Medicações",
        "descricao": "Permite visualizar medicações de pacientes",
        "recurso": "medications",
        "acao": "read"
    },
    {
        "id": "medications.update",
        "categoria": "Medicações",
        "nome": "Editar Medicação",
        "descricao": "Permite editar medicações cadastradas",
        "recurso": "medications",
        "acao": "update"
    },
    {
        "id": "medications.delete",
        "categoria": "Medicações",
        "nome": "Excluir Medicação",
        "descricao": "Permite excluir medicações cadastradas",
        "recurso": "medications",
        "acao": "delete"
    },

    # ===== CHECKLIST (3 permissões) =====
    {
        "id": "checklist.create",
        "categoria": "Checklist",
        "nome": "Criar Item de Checklist",
        "descricao": "Permite criar itens de checklist",
        "recurso": "checklist",
        "acao": "create"
    },
    {
        "id": "checklist.read",
        "categoria": "Checklist",
        "nome": "Ver Checklist",
        "descricao": "Permite visualizar checklist de pacientes",
        "recurso": "checklist",
        "acao": "read"
    },
    {
        "id": "checklist.update",
        "categoria": "Checklist",
        "nome": "Atualizar Checklist",
        "descricao": "Permite atualizar itens de checklist",
        "recurso": "checklist",
        "acao": "update"
    },

    # ===== ORIENTAÇÕES (3 permissões) =====
    {
        "id": "guidelines.create",
        "categoria": "Orientações",
        "nome": "Criar Orientação",
        "descricao": "Permite criar orientações para pacientes",
        "recurso": "guidelines",
        "acao": "create"
    },
    {
        "id": "guidelines.read",
        "categoria": "Orientações",
        "nome": "Ver Orientações",
        "descricao": "Permite visualizar orientações de pacientes",
        "recurso": "guidelines",
        "acao": "read"
    },
    {
        "id": "guidelines.update",
        "categoria": "Orientações",
        "nome": "Editar Orientação",
        "descricao": "Permite editar orientações cadastradas",
        "recurso": "guidelines",
        "acao": "update"
    },

    # ===== DIÁRIO DO TÉCNICO (3 permissões) =====
    {
        "id": "diary.create",
        "categoria": "Diário",
        "nome": "Criar Registro no Diário",
        "descricao": "Permite criar registros no diário do técnico",
        "recurso": "diary",
        "acao": "create"
    },
    {
        "id": "diary.read",
        "categoria": "Diário",
        "nome": "Ver Diário",
        "descricao": "Permite visualizar diário do paciente",
        "recurso": "diary",
        "acao": "read"
    },
    {
        "id": "diary.update",
        "categoria": "Diário",
        "nome": "Editar Registro",
        "descricao": "Permite editar registros do diário",
        "recurso": "diary",
        "acao": "update"
    },

    # ===== RELATÓRIOS MÉDICOS (3 permissões) =====
    {
        "id": "medical_reports.create",
        "categoria": "Relatórios Médicos",
        "nome": "Criar Relatório Médico",
        "descricao": "Permite criar relatórios médicos",
        "recurso": "medical_reports",
        "acao": "create"
    },
    {
        "id": "medical_reports.read",
        "categoria": "Relatórios Médicos",
        "nome": "Ver Relatórios",
        "descricao": "Permite visualizar relatórios médicos",
        "recurso": "medical_reports",
        "acao": "read"
    },
    {
        "id": "medical_reports.update",
        "categoria": "Relatórios Médicos",
        "nome": "Editar Relatório",
        "descricao": "Permite editar relatórios médicos",
        "recurso": "medical_reports",
        "acao": "update"
    },

    # ===== GESTÃO DE EQUIPE (4 permissões) =====
    {
        "id": "team.read",
        "categoria": "Gestão de Equipe",
        "nome": "Ver Equipe",
        "descricao": "Permite visualizar lista da equipe",
        "recurso": "team",
        "acao": "read"
    },
    {
        "id": "team.invite",
        "categoria": "Gestão de Equipe",
        "nome": "Convidar Membro",
        "descricao": "Permite convidar novos membros para a equipe",
        "recurso": "team",
        "acao": "invite"
    },
    {
        "id": "team.update_role",
        "categoria": "Gestão de Equipe",
        "nome": "Alterar Perfil",
        "descricao": "Permite alterar perfil de usuários",
        "recurso": "team",
        "acao": "update_role"
    },
    {
        "id": "team.update_status",
        "categoria": "Gestão de Equipe",
        "nome": "Ativar/Desativar Usuário",
        "descricao": "Permite ativar ou desativar usuários",
        "recurso": "team",
        "acao": "update_status"
    },

    # ===== DASHBOARD (2 permissões) =====
    {
        "id": "dashboard.view_own",
        "categoria": "Dashboard",
        "nome": "Ver Próprio Dashboard",
        "descricao": "Permite visualizar próprio dashboard com estatísticas",
        "recurso": "dashboard",
        "acao": "view_own"
    },
    {
        "id": "dashboard.view_team",
        "categoria": "Dashboard",
        "nome": "Ver Dashboard da Equipe",
        "descricao": "Permite visualizar dashboard com dados da equipe",
        "recurso": "dashboard",
        "acao": "view_team"
    },

    # ===== CONFIGURAÇÕES (2 permissões) =====
    {
        "id": "settings.manage_business",
        "categoria": "Configurações",
        "nome": "Gerenciar Configurações",
        "descricao": "Permite gerenciar configurações do negócio",
        "recurso": "settings",
        "acao": "manage_business"
    },
    {
        "id": "settings.manage_permissions",
        "categoria": "Configurações",
        "nome": "Gerenciar Permissões",
        "descricao": "Permite gerenciar perfis e permissões (admin)",
        "recurso": "settings",
        "acao": "manage_permissions"
    },
]

# Total: 40 permissões genéricas


def get_all_permissions() -> list:
    """Retorna lista de todas as permissões do sistema"""
    return PERMISSIONS_CATALOG


def get_permissions_by_category() -> dict:
    """
    Retorna permissões agrupadas por categoria

    Returns:
        dict: {
            "Pacientes": [lista de permissões],
            "Plano de Cuidados": [lista de permissões],
            ...
        }
    """
    result = {}
    for perm in PERMISSIONS_CATALOG:
        category = perm["categoria"]
        if category not in result:
            result[category] = []
        result[category].append(perm)
    return result


def get_permission_by_id(permission_id: str) -> dict:
    """
    Retorna permissão específica por ID

    Args:
        permission_id: ID da permissão (ex: "patients.create")

    Returns:
        dict: Dados da permissão ou None se não encontrado
    """
    for perm in PERMISSIONS_CATALOG:
        if perm["id"] == permission_id:
            return perm
    return None


def validate_permissions(permission_ids: list) -> tuple:
    """
    Valida se uma lista de IDs de permissões é válida

    Args:
        permission_ids: Lista de IDs para validar

    Returns:
        tuple: (is_valid: bool, invalid_ids: list)
    """
    valid_ids = {perm["id"] for perm in PERMISSIONS_CATALOG}
    invalid_ids = [pid for pid in permission_ids if pid not in valid_ids]

    is_valid = len(invalid_ids) == 0
    return is_valid, invalid_ids
