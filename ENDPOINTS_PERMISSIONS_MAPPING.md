# Mapeamento de Endpoints para Permissões RBAC

## Funções Hardcoded a Substituir

### Funções que verificam ROLES (a serem substituídas por `@require_permission`):

1. **`get_current_admin_user`** - Verifica se é admin
   - Substituir por permissão adequada ao contexto (ex: `team.invite`, `settings.manage_business`)

2. **`get_current_admin_or_profissional_user`** - Verifica se é admin OU profissional
   - Substituir por permissão adequada (ex: `patients.create`, `consultations.create`)

3. **`get_current_profissional_user`** - Verifica se é profissional
   - Substituir por permissão adequada (ex: `diary.create`)

4. **`get_paciente_autorizado`** - Verifica acesso ao paciente (CRÍTICO!)
   - Substituir por `@require_permission` MAS manter lógica de validação de vínculo

5. **`get_admin_or_profissional_autorizado_paciente`** - Verifica se é admin/profissional E autorizado
   - Substituir por permissão adequada + validação de vínculo

6. **`get_current_tecnico_user`** - Verifica se é técnico
   - Substituir por permissão adequada

7. **`get_current_medico_user`** - Verifica se é médico
   - Substituir por `medical_reports.*` permissions

## Mapeamento Endpoints → Permissões

### PACIENTES

| Endpoint | Função Atual | Nova Permissão |
|----------|--------------|----------------|
| `POST /pacientes` | `get_current_admin_or_profissional_user` | `patients.create` |
| `GET /pacientes` | `get_current_admin_or_profissional_user` | `patients.read` |
| `GET /pacientes/{id}` | `get_admin_or_profissional_autorizado_paciente` | `patients.read` + validar vínculo |
| `PUT /pacientes/{id}` | `get_admin_or_profissional_autorizado_paciente` | `patients.update` + validar vínculo |
| `DELETE /pacientes/{id}` | `get_current_admin_user` | `patients.delete` |
| `POST /pacientes/{id}/vincular-enfermeiro` | `get_admin_or_profissional_autorizado_paciente` | `patients.link_team` + validar vínculo |
| `POST /pacientes/{id}/vincular-tecnico` | `get_admin_or_profissional_autorizado_paciente` | `patients.link_team` + validar vínculo |

### ANAMNESE

| Endpoint | Função Atual | Nova Permissão |
|----------|--------------|----------------|
| `POST /pacientes/{id}/anamnese` | `get_paciente_autorizado_anamnese` | `anamnese.create` + validar vínculo |
| `GET /pacientes/{id}/anamnese` | `get_paciente_autorizado` | `anamnese.read` + validar vínculo |
| `PUT /pacientes/{id}/anamnese` | `get_paciente_autorizado_anamnese` | `anamnese.update` + validar vínculo |

### PLANO DE CUIDADOS / CONSULTAS

| Endpoint | Função Atual | Nova Permissão |
|----------|--------------|----------------|
| `POST /pacientes/{id}/consultas` | `get_admin_or_profissional_autorizado_paciente` | `consultations.create` + validar vínculo |
| `GET /pacientes/{id}/consultas` | `get_paciente_autorizado` | `consultations.read` + validar vínculo |
| `PUT /consultas/{id}` | `get_paciente_autorizado` | `consultations.update` + validar vínculo |

### EXAMES

| Endpoint | Função Atual | Nova Permissão |
|----------|--------------|----------------|
| `POST /pacientes/{id}/exames` | `get_admin_or_profissional_autorizado_paciente` | `exams.create` + validar vínculo |
| `GET /pacientes/{id}/exames` | `get_paciente_autorizado` | `exams.read` + validar vínculo |
| `PUT /exames/{id}` | `get_admin_or_profissional_autorizado_paciente` | `exams.update` + validar vínculo |

### MEDICAÇÕES

| Endpoint | Função Atual | Nova Permissão |
|----------|--------------|----------------|
| `POST /pacientes/{id}/medicamentos` | `get_admin_or_profissional_autorizado_paciente` | `medications.create` + validar vínculo |
| `GET /pacientes/{id}/medicamentos` | `get_paciente_autorizado` | `medications.read` + validar vínculo |
| `PUT /medicamentos/{id}` | `get_admin_or_profissional_autorizado_paciente` | `medications.update` + validar vínculo |

### ORIENTAÇÕES

| Endpoint | Função Atual | Nova Permissão |
|----------|--------------|----------------|
| `POST /pacientes/{id}/orientacoes` | `get_admin_or_profissional_autorizado_paciente` | `guidelines.create` + validar vínculo |
| `GET /pacientes/{id}/orientacoes` | `get_paciente_autorizado` | `guidelines.read` + validar vínculo |
| `PUT /orientacoes/{id}` | `get_admin_or_profissional_autorizado_paciente` | `guidelines.update` + validar vínculo |

### CHECKLIST

| Endpoint | Função Atual | Nova Permissão |
|----------|--------------|----------------|
| `POST /pacientes/{id}/checklist` | `get_admin_or_profissional_autorizado_paciente` | `checklist.create` + validar vínculo |
| `GET /pacientes/{id}/checklist` | `get_paciente_autorizado` | `checklist.read` + validar vínculo |
| `PUT /checklist/{id}` | `get_paciente_autorizado` | `checklist.update` + validar vínculo |

### DIÁRIO (REGISTROS) ⚠️ PROBLEMA ATUAL!

| Endpoint | Função Atual | Nova Permissão |
|----------|--------------|----------------|
| `POST /pacientes/{id}/registros` | `get_current_profissional_user` | `diary.create` |
| `GET /pacientes/{id}/registros` | `get_paciente_autorizado` ❌ | `diary.read` + validar vínculo |
| `PUT /registros/{id}` | `get_current_profissional_user` | `diary.update` |
| `POST /pacientes/{id}/diario` (legado) | `get_current_profissional_user` | `diary.create` |
| `GET /pacientes/{id}/diario` (legado) | `get_paciente_autorizado` | `diary.read` + validar vínculo |

### RELATÓRIOS MÉDICOS

| Endpoint | Função Atual | Nova Permissão |
|----------|--------------|----------------|
| `POST /relatorios` | `get_current_medico_user` | `medical_reports.create` |
| `GET /relatorios/{id}` | `get_relatorio_autorizado` | `medical_reports.read` + validar vínculo |
| `PUT /relatorios/{id}` | `get_current_medico_user` | `medical_reports.update` |

### EQUIPE

| Endpoint | Função Atual | Nova Permissão |
|----------|--------------|----------------|
| `GET /negocios/{id}/usuarios` | `get_current_admin_or_profissional_user` | `team.read` |
| `POST /negocios/{id}/usuarios/convidar` | `get_current_admin_user` | `team.invite` |
| `PUT /usuarios/{id}/role` | `get_current_admin_user` | `team.update_role` |
| `PUT /usuarios/{id}/ativo` | `get_current_admin_user` | `team.update_status` |

## Estratégia de Implementação

### Fase 1: Criar nova função `get_patient_authorized_with_permission`
Esta função irá:
1. Verificar se usuário tem a permissão necessária
2. Validar vínculo com o paciente (próprio paciente, admin, enfermeiro vinculado, técnico vinculado)
3. Retornar o usuário autenticado OU lançar 403

### Fase 2: Substituir todos os `Depends(get_*)` por `@require_permission`
- Usar `@require_permission` para endpoints simples (sem validação de vínculo)
- Usar `get_patient_authorized_with_permission` para endpoints que precisam validar vínculo

### Fase 3: Deprecar funções antigas
- Manter apenas `get_current_user_firebase` (autenticação base)
- Remover todas as outras funções `get_*` hardcoded
