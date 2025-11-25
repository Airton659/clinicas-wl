# PLANO: Backend + Frontend Multi-Tenant para Clínicas

## Objetivo
Criar arquitetura completa (backend + frontend) que suporta múltiplas empresas (white-label), aproveitando código que JÁ FUNCIONA.

## Estrutura

```
clinicas-wl/
├── backend-core/                  # Código backend compartilhado (do barbearia-backend)
│   ├── main.py
│   ├── auth.py
│   ├── crud.py
│   ├── database.py
│   ├── schemas.py
│   ├── crypto_utils.py
│   ├── crud_plano_ack.py
│   ├── requirements.txt
│   └── Dockerfile
│
├── frontend-core/                 # Código frontend compartilhado (do analicegrubert)
│   ├── lib/
│   ├── web/
│   ├── pubspec.yaml
│   └── (todos os arquivos Flutter)
│
├── clientes/
│   ├── clinica-medica/           # Tenant 1
│   │   ├── backend/              # Cópia backend-core + config
│   │   └── frontend/             # Cópia frontend-core + config
│   │
│   └── clinica-vet/              # Tenant 2
│       ├── backend/              # Cópia backend-core + config
│       └── frontend/             # Cópia frontend-core + config
│
└── scripts/
    ├── sync-cores.sh             # Sincroniza ambos cores → clientes
    ├── deploy-backend.sh         # Deploy backend de 1 cliente
    ├── deploy-frontend.sh        # Deploy frontend de 1 cliente
    └── deploy-all.sh             # Deploy completo (back+front) de 1 cliente
```

## Como Funciona

### 1. Cores (código compartilhado)

**backend-core/**:
- **Origem**: Cópia do `/Users/joseairton/Documents/AG/barbearia-backend` (commit de5de5e - FUNCIONANDO)
- **Conteúdo**: Todo código Python, Dockerfile, requirements.txt
- **Modificação**: Remove APENAS tentativas multi-tenant quebradas (se houver)

**frontend-core/**:
- **Origem**: Cópia do `/Users/joseairton/Documents/AG/analicegrubert` (Git HEAD - produção)
- **Conteúdo**: Todo código Flutter
- **Modificação**: Nenhuma inicialmente

### 2. Clientes (tenants)
Cada cliente tem backend E frontend separados:
  - **backend/**: Cópia do backend-core/ + config.yaml + deploy.sh
  - **frontend/**: Cópia do frontend-core/ + config.yaml + .firebaserc customizado

### 3. Scripts de Automação

**sync-cores.sh**:
- Copia backend-core/ → clientes/*/backend/
- Copia frontend-core/ → clientes/*/frontend/
- Preserva configs de cada cliente

**deploy-backend.sh**:
- Deploy backend de 1 cliente
- Uso: `./scripts/deploy-backend.sh clinica-medica`

**deploy-frontend.sh**:
- Deploy frontend de 1 cliente
- Uso: `./scripts/deploy-frontend.sh clinica-medica`

**deploy-all.sh**:
- Deploy backend + frontend de 1 cliente
- Uso: `./scripts/deploy-all.sh clinica-medica`

## Workflow de Atualização

1. Editar código em `backend-core/` ou `frontend-core/`
2. Rodar `./scripts/sync-cores.sh`
3. Testar em 1 cliente: `./scripts/deploy-all.sh clinica-medica`
4. Se funcionar, deploy em outros clientes

## Deploy de Cada Cliente

Cada cliente é completamente isolado:
- **Backend**: Cloud Run service próprio
- **Frontend**: Firebase Hosting próprio
- **Firebase**: Auth + Firestore próprios
- **Impossível** um cliente acessar dados de outro

## O que NÃO mexe

❌ `/Users/joseairton/Documents/AG/barbearia-backend` (produção)
❌ `/Users/joseairton/Documents/AG/analicegrubert` (frontend produção)
❌ Qualquer coisa em produção

## Tenants Iniciais

1. **clinica-medica**: Clínica médica genérica (para testes)
2. **clinica-vet**: Clínica veterinária genérica (para testes)

Depois de validar a arquitetura, podemos adicionar o pilot como tenant.

## Garantias

✅ Código base = o que JÁ funciona em produção
✅ Cada cliente totalmente isolado
✅ Atualização única (core) aplicada a todos
✅ Produção intocada
✅ Testável antes de afetar qualquer cliente real
