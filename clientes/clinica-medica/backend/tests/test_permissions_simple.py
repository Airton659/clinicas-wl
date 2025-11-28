"""
Teste Simples de Permissões RBAC - Validação Lógica

Este script valida a LÓGICA do sistema de permissões sem fazer chamadas HTTP.
Testa se o sistema corretamente:
1. Carrega permissões de roles genéricas (perfil_1, perfil_2, etc.)
2. Verifica permissões corretamente
3. NÃO verifica tipo de role

Uso:
    python3 test_permissions_simple.py
"""

import sys
import os

# Adicionar o diretório pai ao path para importar os módulos
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# =============================================================================
# MOCK DO FIREBASE PARA TESTES
# =============================================================================

class MockFirestore:
    """Mock do Firestore para testes"""

    def __init__(self):
        self.data = {
            "roles": {
                "role_admin": {
                    "tipo": "perfil_admin",
                    "nivel_hierarquico": 1,
                    "nome_customizado": "Administrador",
                    "permissions": ["patients.read", "patients.create", "patients.update", "patients.delete",
                                   "diary.read", "diary.create", "diary.update", "team.read", "team.invite"]
                },
                "role_mecanico": {
                    "tipo": "perfil_1",
                    "nivel_hierarquico": 5,
                    "nome_customizado": "Mecânico",
                    "permissions": ["diary.read", "diary.create", "diary.update"]
                },
                "role_enfermeiro": {
                    "tipo": "perfil_2",
                    "nivel_hierarquico": 3,
                    "nome_customizado": "Enfermeiro",
                    "permissions": ["patients.read", "diary.read", "diary.create"]
                },
                "role_sem_permissoes": {
                    "tipo": "perfil_3",
                    "nivel_hierarquico": 8,
                    "nome_customizado": "Visitante",
                    "permissions": []
                }
            },
            "usuarios": {
                "user_admin": {
                    "nome": "Admin User",
                    "email": "admin@test.com",
                    "roles": {"negocio_123": "role_admin"}
                },
                "user_mecanico": {
                    "nome": "Mecânico User",
                    "email": "mecanico@test.com",
                    "roles": {"negocio_123": "role_mecanico"}
                },
                "user_enfermeiro": {
                    "nome": "Enfermeiro User",
                    "email": "enfermeiro@test.com",
                    "roles": {"negocio_123": "role_enfermeiro"}
                },
                "user_sem_perms": {
                    "nome": "Visitante User",
                    "email": "visitante@test.com",
                    "roles": {"negocio_123": "role_sem_permissoes"}
                }
            }
        }

    def collection(self, name):
        return MockCollection(self.data.get(name, {}))


class MockCollection:
    def __init__(self, data):
        self.data = data

    def document(self, doc_id):
        return MockDocument(self.data.get(doc_id, {}))


class MockDocument:
    def __init__(self, data):
        self.data = data

    def get(self):
        return self

    @property
    def exists(self):
        return len(self.data) > 0

    def to_dict(self):
        return self.data


# =============================================================================
# SISTEMA DE PERMISSÕES (copiado do auth.py)
# =============================================================================

_permissions_cache = {}

def get_user_permissions(db, user_id: str, negocio_id: str):
    """
    Versão simplificada do get_user_permissions do auth.py
    """
    # Buscar usuário
    user_doc = db.collection("usuarios").document(user_id).get()
    if not user_doc.exists:
        return []

    user_data = user_doc.to_dict()
    roles = user_data.get("roles", {})

    # Verificar role do usuário neste negócio
    role_value = roles.get(negocio_id)
    if not role_value:
        return []

    # RBAC GENÉRICO: role_value é um ID de documento na collection 'roles'
    role_id = role_value
    role_doc = db.collection("roles").document(role_id).get()

    if not role_doc.exists:
        return []

    role_data = role_doc.to_dict()
    permissions = role_data.get("permissions", [])

    return permissions


def check_permission(db, user_id: str, permission: str, negocio_id: str) -> bool:
    """Verifica se usuário tem permissão específica"""
    permissions = get_user_permissions(db, user_id, negocio_id)
    return permission in permissions


# =============================================================================
# TESTES
# =============================================================================

class PermissionLogicTester:
    """Testa a lógica do sistema de permissões"""

    def __init__(self):
        self.db = MockFirestore()
        self.results = {
            "total": 0,
            "passed": 0,
            "failed": 0,
            "errors": []
        }

    def test_case(self, name: str, user_id: str, permission: str, negocio_id: str, should_have: bool):
        """Testa um caso específico"""
        self.results["total"] += 1

        has_permission = check_permission(self.db, user_id, permission, negocio_id)

        if has_permission == should_have:
            self.results["passed"] += 1
            status = "✅ PASSOU"
        else:
            self.results["failed"] += 1
            status = "❌ FALHOU"
            self.results["errors"].append(f"{name}: Esperado {should_have}, obteve {has_permission}")

        print(f"{status} - {name}")
        return has_permission == should_have

    def run_all_tests(self):
        """Executa todos os testes"""
        print("\n" + "="*80)
        print("TESTES DE LÓGICA DO SISTEMA RBAC")
        print("="*80)

        # Teste 1: Admin tem permissões
        print("\n📋 Teste 1: Verificar permissões do Admin")
        self.test_case("Admin tem patients.read", "user_admin", "patients.read", "negocio_123", True)
        self.test_case("Admin tem patients.create", "user_admin", "patients.create", "negocio_123", True)
        self.test_case("Admin tem diary.read", "user_admin", "diary.read", "negocio_123", True)
        self.test_case("Admin tem team.invite", "user_admin", "team.invite", "negocio_123", True)

        # Teste 2: Mecânico (perfil_1) tem permissões de diário
        print("\n📋 Teste 2: Verificar permissões do Mecânico (perfil_1)")
        self.test_case("Mecânico tem diary.read", "user_mecanico", "diary.read", "negocio_123", True)
        self.test_case("Mecânico tem diary.create", "user_mecanico", "diary.create", "negocio_123", True)
        self.test_case("Mecânico tem diary.update", "user_mecanico", "diary.update", "negocio_123", True)
        self.test_case("Mecânico NÃO tem patients.create", "user_mecanico", "patients.create", "negocio_123", False)
        self.test_case("Mecânico NÃO tem team.invite", "user_mecanico", "team.invite", "negocio_123", False)

        # Teste 3: Enfermeiro (perfil_2) tem permissões limitadas
        print("\n📋 Teste 3: Verificar permissões do Enfermeiro (perfil_2)")
        self.test_case("Enfermeiro tem patients.read", "user_enfermeiro", "patients.read", "negocio_123", True)
        self.test_case("Enfermeiro tem diary.read", "user_enfermeiro", "diary.read", "negocio_123", True)
        self.test_case("Enfermeiro tem diary.create", "user_enfermeiro", "diary.create", "negocio_123", True)
        self.test_case("Enfermeiro NÃO tem diary.update", "user_enfermeiro", "diary.update", "negocio_123", False)
        self.test_case("Enfermeiro NÃO tem patients.delete", "user_enfermeiro", "patients.delete", "negocio_123", False)

        # Teste 4: Visitante (perfil_3) não tem permissões
        print("\n📋 Teste 4: Verificar que Visitante NÃO tem permissões")
        self.test_case("Visitante NÃO tem diary.read", "user_sem_perms", "diary.read", "negocio_123", False)
        self.test_case("Visitante NÃO tem patients.read", "user_sem_perms", "patients.read", "negocio_123", False)
        self.test_case("Visitante NÃO tem team.invite", "user_sem_perms", "team.invite", "negocio_123", False)

        # Teste 5: Usuário inexistente
        print("\n📋 Teste 5: Verificar usuário inexistente")
        self.test_case("Usuário inexistente NÃO tem permissões", "user_fake", "diary.read", "negocio_123", False)

        # Teste 6: Negócio errado
        print("\n📋 Teste 6: Verificar negócio errado")
        self.test_case("Admin em negócio errado NÃO tem permissões", "user_admin", "diary.read", "negocio_999", False)

        # Teste 7: CRÍTICO - Sistema NÃO verifica tipo de role
        print("\n📋 Teste 7: CRÍTICO - Sistema ignora tipo de role (perfil_X)")
        print("   (Todas as roles são tratadas igualmente, apenas permissões importam)")
        perms_mecanico = get_user_permissions(self.db, "user_mecanico", "negocio_123")
        perms_enfermeiro = get_user_permissions(self.db, "user_enfermeiro", "negocio_123")

        # Verificar que ambos têm diary.read, independente de serem perfil_1 ou perfil_2
        has_diary_mecanico = "diary.read" in perms_mecanico
        has_diary_enfermeiro = "diary.read" in perms_enfermeiro

        if has_diary_mecanico and has_diary_enfermeiro:
            print(f"✅ PASSOU - Ambos perfil_1 e perfil_2 podem ter diary.read")
            self.results["passed"] += 1
        else:
            print(f"❌ FALHOU - Sistema está verificando tipo de role!")
            self.results["failed"] += 1
            self.results["errors"].append("Sistema verifica tipo de role ao invés de permissões")
        self.results["total"] += 1

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
                print(f"  - {error}")

        # Taxa de sucesso
        success_rate = (self.results['passed'] / self.results['total']) * 100 if self.results['total'] > 0 else 0
        print(f"\n📈 Taxa de sucesso: {success_rate:.1f}%")

        if success_rate == 100:
            print("\n🎉 TODOS OS TESTES PASSARAM!")
            print("✅ Sistema RBAC está funcionando corretamente")
            print("✅ Permissões são verificadas, NÃO tipos de role")
            print("✅ Roles customizadas (perfil_1, perfil_2, etc.) funcionam perfeitamente")
        else:
            print("\n❌ SISTEMA RBAC PRECISA DE CORREÇÕES")

        return success_rate == 100


# =============================================================================
# SCRIPT PRINCIPAL
# =============================================================================

def main():
    """Executa os testes"""
    tester = PermissionLogicTester()
    tester.run_all_tests()


if __name__ == "__main__":
    main()
