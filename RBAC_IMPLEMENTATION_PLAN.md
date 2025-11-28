# Plano de Implementação do Sistema RBAC - Fase 2

## Status Atual
✅ **Concluído - Fase 1:**
- Models criados (Role, Permission, RolePermission, UserRole)
- Endpoints de gestão de roles e permissões
- 40 permissões pré-definidas seedadas
- Sistema básico de verificação de permissões
- Frontend com Role model

## Próximos Passos - Fase 2

### 1. Integração das Permissões em Todo o Backend
**Objetivo:** Proteger todos os endpoints com verificação de permissões

**Arquivos a modificar:**
- `routers/usuarios_router.py`
- `routers/pacientes_router.py`
- `routers/agenda_router.py`
- `routers/prontuario_router.py`
- `routers/financeiro_router.py`
- `routers/relatorios_router.py`

**Padrão a aplicar:**
```python
@router.get("/endpoint")
@require_permission("permissao.necessaria")
async def endpoint_handler(...):
    ...
```

### 2. Atualização do Frontend para Usar Permissões
**Objetivo:** Controlar visibilidade de UI baseado em permissões do usuário

**Componentes a criar:**
- `PermissionGuard` widget (verifica se usuário tem permissão)
- `PermissionBuilder` widget (constrói UI condicionalmente)
- `permission_service.dart` (cache e verificação de permissões)

**Páginas a atualizar:**
- Todas as páginas principais para usar guards de permissão
- Menu lateral para esconder itens sem permissão
- Botões de ação para desabilitar quando sem permissão

### 3. Tela de Gestão de Roles no Frontend
**Objetivo:** Interface administrativa para criar/editar roles

**Telas a criar:**
- `roles_management_page.dart` - Lista de roles
- `role_editor_page.dart` - Edição de role individual
- `permission_selector_widget.dart` - Seletor de permissões

**Funcionalidades:**
- Listar todas as roles do negócio
- Criar nova role customizada
- Editar permissions de uma role
- Atribuir cores e ícones às roles
- Visualizar hierarquia de roles

### 4. Gestão de Usuários com Roles
**Objetivo:** Atribuir roles aos usuários

**Modificações:**
- Atualizar tela de criação de usuário para selecionar role
- Atualizar tela de edição de usuário para trocar role
- Mostrar role atual do usuário na lista
- Validar que apenas usuários com permissão podem atribuir roles

### 5. Sistema de Auditoria
**Objetivo:** Registrar mudanças em roles e permissões

**Implementar:**
- Logging de criação/edição/exclusão de roles
- Logging de atribuição de roles a usuários
- Endpoint para visualizar histórico de mudanças
- Interface no frontend para ver audit logs

### 6. Testes
**Objetivo:** Garantir que o sistema funciona corretamente

**Criar:**
- Testes unitários das permissions
- Testes de integração dos endpoints protegidos
- Testes de UI para guards de permissão
- Testes de edge cases (usuário sem role, role sem permissões, etc.)

## Ordem de Implementação Recomendada

1. ✅ **CONCLUÍDO** - Criar models e endpoints base
2. ✅ **CONCLUÍDO** - Seedar permissões iniciais
3. **PRÓXIMO** - Integrar permissões em endpoints críticos (pacientes, prontuário)
4. Criar widgets de permissão no frontend (PermissionGuard, etc.)
5. Atualizar frontend para usar guards de permissão
6. Criar tela de gestão de roles
7. Atualizar gestão de usuários para atribuir roles
8. Implementar auditoria
9. Testes automatizados

## Notas Importantes

- Sempre verificar permissões no backend, nunca confiar apenas no frontend
- Roles de sistema (admin, medico, recepcionista, etc.) não podem ser deletadas
- Hierarquia de níveis deve ser respeitada (admin > médico > recepcionista)
- Permissões são granulares: view, create, update, delete por módulo
- Super Admin (role="platform") tem acesso total a tudo

## Estimativa de Tempo

- Fase 2 (Integração Backend): ~3-4 horas
- Fase 3 (Frontend Guards): ~4-5 horas
- Fase 4 (Gestão de Roles UI): ~6-8 horas
- Fase 5 (Gestão de Usuários): ~2-3 horas
- Fase 6 (Auditoria): ~3-4 horas
- Fase 7 (Testes): ~4-6 horas

**Total estimado:** 22-30 horas de desenvolvimento
