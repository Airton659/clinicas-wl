# Testes Automatizados de Permissões RBAC

Este diretório contém testes automatizados para validar o sistema de permissões RBAC.

## Arquivos de Teste

### 1. `test_permissions_simple.py` ⭐ RECOMENDADO

**Teste de lógica SEM necessidade de configuração**

Valida a lógica do sistema de permissões usando dados mock. Não faz chamadas HTTP.

**Como executar:**
```bash
cd /Users/joseairton/Documents/AG/clinicas-wl/backend-core
python3 tests/test_permissions_simple.py
```

**O que testa:**
- ✅ Roles genéricas (`perfil_1`, `perfil_2`, etc.) funcionam
- ✅ Permissões são verificadas corretamente
- ✅ Sistema NÃO verifica tipo de role
- ✅ Usuários COM permissão têm acesso
- ✅ Usuários SEM permissão são bloqueados

**Resultado esperado:**
```
📊 Total de testes: 20
✅ Passaram: 20
❌ Falharam: 0
📈 Taxa de sucesso: 100.0%
```

---

### 2. `test_permissions.py`

**Teste de integração COM chamadas HTTP reais**

Testa todas as 40 permissões do sistema fazendo requisições HTTP para a API.

**Pré-requisitos:**
1. Backend rodando (local ou em produção)
2. Tokens de autenticação válidos do Firebase
3. IDs de teste (negocio_id, paciente_id)

**Como configurar:**
1. Abra `test_permissions.py`
2. Atualize as constantes no topo:
```python
API_BASE_URL = "https://sua-api.run.app"
TOKENS = {
    "admin": "seu_token_admin",
    "user_with_all_permissions": "seu_token_user_com_perms",
    "user_without_permissions": "seu_token_user_sem_perms",
}
TEST_NEGOCIO_ID = "seu_negocio_id"
TEST_PACIENTE_ID = "seu_paciente_id"
```

**Como executar:**
```bash
pip3 install requests  # Se ainda não tiver
cd /Users/joseairton/Documents/AG/clinicas-wl/backend-core
python3 tests/test_permissions.py
```

**O que testa:**
- ✅ Todas as 40 permissões do sistema
- ✅ Endpoints respondem corretamente
- ✅ Usuários COM permissão recebem 200-299 ou 404
- ✅ Usuários SEM permissão recebem 403 Forbidden

---

## Permissões Testadas (40 total)

### Pacientes (5)
- `patients.create` - Criar paciente
- `patients.read` - Ver pacientes
- `patients.update` - Editar paciente
- `patients.delete` - Excluir paciente
- `patients.link_team` - Vincular equipe

### Consultas (4)
- `consultations.create`
- `consultations.read`
- `consultations.update`
- `consultations.delete`

### Anamnese (3)
- `anamnese.create`
- `anamnese.read`
- `anamnese.update`

### Exames (4)
- `exams.create`
- `exams.read`
- `exams.update`
- `exams.delete`

### Medicações (4)
- `medications.create`
- `medications.read`
- `medications.update`
- `medications.delete`

### Checklist (3)
- `checklist.create`
- `checklist.read`
- `checklist.update`

### Orientações (3)
- `guidelines.create`
- `guidelines.read`
- `guidelines.update`

### Diário (3) ⚠️ CRÍTICO
- `diary.create`
- `diary.read` ⭐ Principal teste
- `diary.update`

### Relatórios Médicos (3)
- `medical_reports.create`
- `medical_reports.read`
- `medical_reports.update`

### Equipe (4)
- `team.read`
- `team.invite`
- `team.update_role`
- `team.update_status`

### Dashboard (2)
- `dashboard.view_own`
- `dashboard.view_team`

### Configurações (2)
- `settings.manage_business`
- `settings.manage_permissions`

---

## Interpretação dos Resultados

### ✅ Teste PASSOU
- Sistema está funcionando corretamente
- Permissões estão sendo verificadas
- Tipos de role (`perfil_X`) são ignorados

### ❌ Teste FALHOU
- Sistema pode estar verificando tipo de role
- Endpoint não está usando `@require_permission`
- Permissão não está sendo verificada corretamente

---

## Solução de Problemas

### "Módulo não encontrado"
```bash
# Certifique-se de estar no diretório correto
cd /Users/joseairton/Documents/AG/clinicas-wl/backend-core
python3 tests/test_permissions_simple.py
```

### "Token inválido" (test_permissions.py)
1. Gere um novo token do Firebase
2. Atualize a constante `TOKENS` no arquivo
3. Tokens expiram! Gere novos se necessário

### "Conexão recusada" (test_permissions.py)
1. Verifique se o backend está rodando
2. Confirme o `API_BASE_URL`
3. Teste manualmente com curl primeiro

---

## Próximos Passos

Após corrigir o sistema RBAC:
1. ✅ Rodar `test_permissions_simple.py` → Deve passar 100%
2. ⏭️ Configurar e rodar `test_permissions.py` → Validar endpoints reais
3. ⏭️ Testar manualmente no app com role customizada

---

## Contribuindo

Ao adicionar novas permissões:
1. Adicione à lista em `permissions_catalog.py`
2. Adicione teste em `test_permissions_simple.py`
3. Adicione endpoint em `test_permissions.py`
4. Rode os testes para validar
