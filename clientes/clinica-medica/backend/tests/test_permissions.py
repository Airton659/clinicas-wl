"""
Testes Automatizados do Sistema RBAC de Permissões

Este script testa TODAS as 40 permissões do sistema para garantir que:
1. Usuários COM a permissão conseguem acessar
2. Usuários SEM a permissão são bloqueados
3. O sistema verifica permissões, NÃO tipos de role

Uso:
    python3 test_permissions.py
"""

import requests
import json
from typing import Dict, List, Optional
from datetime import datetime

# =============================================================================
# CONFIGURAÇÃO
# =============================================================================

API_BASE_URL = "https://clinica-medica-backend-388995704994.southamerica-east1.run.app"
# API_BASE_URL = "http://localhost:8000"  # Para testes locais

# Tokens de teste (você precisa gerar tokens válidos do Firebase)
# Estes são exemplos - substitua com tokens reais
TOKENS = {
    "admin": "SEU_TOKEN_ADMIN_AQUI",
    "user_with_all_permissions": "SEU_TOKEN_USER_ALL_PERMS_AQUI",
    "user_without_permissions": "SEU_TOKEN_USER_NO_PERMS_AQUI",
}

# ID de teste
TEST_NEGOCIO_ID = "SEU_NEGOCIO_ID_AQUI"
TEST_PACIENTE_ID = "SEU_PACIENTE_ID_AQUI"

# =============================================================================
# CATÁLOGO DE PERMISSÕES (40 permissões)
# =============================================================================

PERMISSIONS_CATALOG = [
    # PACIENTES (5)
    {"id": "patients.create", "method": "POST", "endpoint": f"/negocios/{TEST_NEGOCIO_ID}/pacientes"},
    {"id": "patients.read", "method": "GET", "endpoint": f"/negocios/{TEST_NEGOCIO_ID}/pacientes"},
    {"id": "patients.update", "method": "PUT", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}"},
    {"id": "patients.delete", "method": "DELETE", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}"},
    {"id": "patients.link_team", "method": "POST", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}/vincular-enfermeiro"},

    # CONSULTAS (4)
    {"id": "consultations.create", "method": "POST", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}/consultas"},
    {"id": "consultations.read", "method": "GET", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}/consultas"},
    {"id": "consultations.update", "method": "PUT", "endpoint": "/consultas/TEST_CONSULTA_ID"},
    {"id": "consultations.delete", "method": "DELETE", "endpoint": "/consultas/TEST_CONSULTA_ID"},

    # ANAMNESE (3)
    {"id": "anamnese.create", "method": "POST", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}/anamnese"},
    {"id": "anamnese.read", "method": "GET", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}/anamnese"},
    {"id": "anamnese.update", "method": "PUT", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}/anamnese"},

    # EXAMES (4)
    {"id": "exams.create", "method": "POST", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}/exames"},
    {"id": "exams.read", "method": "GET", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}/exames"},
    {"id": "exams.update", "method": "PUT", "endpoint": "/exames/TEST_EXAME_ID"},
    {"id": "exams.delete", "method": "DELETE", "endpoint": "/exames/TEST_EXAME_ID"},

    # MEDICAÇÕES (4)
    {"id": "medications.create", "method": "POST", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}/medicamentos"},
    {"id": "medications.read", "method": "GET", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}/medicamentos"},
    {"id": "medications.update", "method": "PUT", "endpoint": "/medicamentos/TEST_MED_ID"},
    {"id": "medications.delete", "method": "DELETE", "endpoint": "/medicamentos/TEST_MED_ID"},

    # CHECKLIST (3)
    {"id": "checklist.create", "method": "POST", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}/checklist"},
    {"id": "checklist.read", "method": "GET", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}/checklist"},
    {"id": "checklist.update", "method": "PUT", "endpoint": "/checklist/TEST_ITEM_ID"},

    # ORIENTAÇÕES (3)
    {"id": "guidelines.create", "method": "POST", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}/orientacoes"},
    {"id": "guidelines.read", "method": "GET", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}/orientacoes"},
    {"id": "guidelines.update", "method": "PUT", "endpoint": "/orientacoes/TEST_ORIENT_ID"},

    # DIÁRIO (3) - CRÍTICO!
    {"id": "diary.create", "method": "POST", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}/diario"},
    {"id": "diary.read", "method": "GET", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}/diario"},
    {"id": "diary.update", "method": "PATCH", "endpoint": f"/pacientes/{TEST_PACIENTE_ID}/diario/TEST_REGISTRO_ID"},

    # RELATÓRIOS MÉDICOS (3)
    {"id": "medical_reports.create", "method": "POST", "endpoint": "/relatorios"},
    {"id": "medical_reports.read", "method": "GET", "endpoint": "/relatorios/TEST_REPORT_ID"},
    {"id": "medical_reports.update", "method": "PUT", "endpoint": "/relatorios/TEST_REPORT_ID"},

    # EQUIPE (4)
    {"id": "team.read", "method": "GET", "endpoint": f"/negocios/{TEST_NEGOCIO_ID}/usuarios"},
    {"id": "team.invite", "method": "POST", "endpoint": f"/negocios/{TEST_NEGOCIO_ID}/usuarios/convidar"},
    {"id": "team.update_role", "method": "PUT", "endpoint": "/usuarios/TEST_USER_ID/role"},
    {"id": "team.update_status", "method": "PUT", "endpoint": "/usuarios/TEST_USER_ID/ativo"},

    # DASHBOARD (2)
    {"id": "dashboard.view_own", "method": "GET", "endpoint": f"/negocios/{TEST_NEGOCIO_ID}/dashboard"},
    {"id": "dashboard.view_team", "method": "GET", "endpoint": f"/negocios/{TEST_NEGOCIO_ID}/dashboard/equipe"},

    # CONFIGURAÇÕES (2)
    {"id": "settings.manage_business", "method": "PUT", "endpoint": f"/negocios/{TEST_NEGOCIO_ID}"},
    {"id": "settings.manage_permissions", "method": "GET", "endpoint": f"/negocios/{TEST_NEGOCIO_ID}/roles"},
]

# =============================================================================
# FUNÇÕES DE TESTE
# =============================================================================

class PermissionTester:
    """Classe para testar permissões RBAC"""

    def __init__(self, base_url: str):
        self.base_url = base_url
        self.results = {
            "total": 0,
            "passed": 0,
            "failed": 0,
            "errors": []
        }

    def test_permission(self, permission: Dict, token: str, should_pass: bool = True) -> bool:
        """
        Testa uma permissão específica

        Args:
            permission: Dict com id, method, endpoint
            token: Token de autenticação
            should_pass: Se True, espera 200-299. Se False, espera 403
        """
        self.results["total"] += 1

        url = f"{self.base_url}{permission['endpoint']}"
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }

        # Dados mock para POST/PUT/PATCH
        mock_data = {
            "nome": "Test",
            "negocio_id": TEST_NEGOCIO_ID,
            "test": True
        }

        try:
            # Fazer requisição
            if permission["method"] == "GET":
                response = requests.get(url, headers=headers, timeout=10)
            elif permission["method"] == "POST":
                response = requests.post(url, headers=headers, json=mock_data, timeout=10)
            elif permission["method"] == "PUT":
                response = requests.put(url, headers=headers, json=mock_data, timeout=10)
            elif permission["method"] == "PATCH":
                response = requests.patch(url, headers=headers, json=mock_data, timeout=10)
            elif permission["method"] == "DELETE":
                response = requests.delete(url, headers=headers, timeout=10)

            # Verificar resultado
            if should_pass:
                # Espera sucesso (200-299) ou 404 (recurso não existe, mas permissão OK)
                success = response.status_code < 400 or response.status_code == 404
                if success:
                    self.results["passed"] += 1
                    print(f"✅ {permission['id']}: PASSOU (status {response.status_code})")
                    return True
                else:
                    self.results["failed"] += 1
                    error = f"❌ {permission['id']}: FALHOU - Esperado sucesso, recebeu {response.status_code}"
                    self.results["errors"].append(error)
                    print(error)
                    return False
            else:
                # Espera falha (403 Forbidden)
                if response.status_code == 403:
                    self.results["passed"] += 1
                    print(f"✅ {permission['id']}: BLOQUEADO corretamente (403)")
                    return True
                else:
                    self.results["failed"] += 1
                    error = f"❌ {permission['id']}: FALHOU - Esperado 403, recebeu {response.status_code}"
                    self.results["errors"].append(error)
                    print(error)
                    return False

        except Exception as e:
            self.results["failed"] += 1
            error = f"❌ {permission['id']}: ERRO - {str(e)}"
            self.results["errors"].append(error)
            print(error)
            return False

    def test_all_permissions(self, token_with_perms: str, token_without_perms: str):
        """
        Testa todas as 40 permissões

        Args:
            token_with_perms: Token de usuário com todas as permissões
            token_without_perms: Token de usuário sem permissões
        """
        print("\n" + "="*80)
        print("INICIANDO TESTES DE PERMISSÕES RBAC")
        print("="*80)

        print("\n📋 Total de permissões a testar:", len(PERMISSIONS_CATALOG))

        # Fase 1: Testar com usuário QUE TEM permissões
        print("\n" + "-"*80)
        print("FASE 1: Testando com usuário COM permissões")
        print("-"*80)

        for permission in PERMISSIONS_CATALOG:
            self.test_permission(permission, token_with_perms, should_pass=True)

        # Fase 2: Testar com usuário SEM permissões
        print("\n" + "-"*80)
        print("FASE 2: Testando com usuário SEM permissões")
        print("-"*80)

        for permission in PERMISSIONS_CATALOG:
            self.test_permission(permission, token_without_perms, should_pass=False)

        # Resultado final
        self.print_summary()

    def print_summary(self):
        """Imprime resumo dos testes"""
        print("\n" + "="*80)
        print("RESUMO DOS TESTES")
        print("="*80)

        print(f"\n📊 Total de testes: {self.results['total']}")
        print(f"✅ Passaram: {self.results['passed']}")
        print(f"❌ Falharam: {self.results['failed']}")

        if self.results['failed'] > 0:
            print("\n⚠️  ERROS ENCONTRADOS:")
            for error in self.results['errors']:
                print(f"  {error}")

        # Taxa de sucesso
        success_rate = (self.results['passed'] / self.results['total']) * 100 if self.results['total'] > 0 else 0
        print(f"\n📈 Taxa de sucesso: {success_rate:.1f}%")

        if success_rate == 100:
            print("\n🎉 TODOS OS TESTES PASSARAM! Sistema RBAC funcionando perfeitamente!")
        elif success_rate >= 90:
            print("\n⚠️  Sistema quase 100%, mas há algumas falhas")
        else:
            print("\n❌ Sistema RBAC precisa de correções")

        return success_rate == 100

# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

def main():
    """Executa os testes"""

    # Verificar configuração
    if "SEU_TOKEN" in TOKENS["admin"]:
        print("\n⚠️  ATENÇÃO: Configure os tokens de teste no topo do arquivo!")
        print("Você precisa:")
        print("1. Gerar tokens válidos do Firebase")
        print("2. Atualizar TOKENS com os tokens reais")
        print("3. Atualizar TEST_NEGOCIO_ID e TEST_PACIENTE_ID")
        print("\nPara gerar tokens, use o Firebase Auth e obtenha o ID Token.")
        return

    # Criar tester
    tester = PermissionTester(API_BASE_URL)

    # Rodar testes
    tester.test_all_permissions(
        token_with_perms=TOKENS["user_with_all_permissions"],
        token_without_perms=TOKENS["user_without_permissions"]
    )

if __name__ == "__main__":
    main()
