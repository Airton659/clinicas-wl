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

## Configuração Necessária para Novos Clientes

Para adicionar um novo cliente, além de criar a estrutura de pastas e configs, é necessário configurar os seguintes recursos no GCP/Firebase:

### 1. APIs que precisam estar habilitadas:
```bash
gcloud services enable cloudkms.googleapis.com --project=<projeto>
gcloud services enable secretmanager.googleapis.com --project=<projeto>
```

### 2. KMS (Cloud Key Management Service):
```bash
# Criar keyring
gcloud kms keyrings create <cliente>-keyring \
  --location=<region> \
  --project=<projeto>

# Criar crypto key
gcloud kms keys create <cliente>-crypto-key \
  --keyring=<cliente>-keyring \
  --location=<region> \
  --purpose=encryption \
  --project=<projeto>
```

### 3. Firebase Admin Service Account:
```bash
# Criar service account
gcloud iam service-accounts create firebase-admin \
  --display-name="Firebase Admin SDK" \
  --project=<projeto>

# Dar permissões
gcloud projects add-iam-policy-binding <projeto> \
  --member="serviceAccount:firebase-admin@<projeto>.iam.gserviceaccount.com" \
  --role="roles/firebase.admin"

gcloud projects add-iam-policy-binding <projeto> \
  --member="serviceAccount:firebase-admin@<projeto>.iam.gserviceaccount.com" \
  --role="roles/datastore.user"

# Criar chave JSON
gcloud iam service-accounts keys create /tmp/firebase-admin.json \
  --iam-account=firebase-admin@<projeto>.iam.gserviceaccount.com \
  --project=<projeto>
```

### 4. Secret Manager:
```bash
# Criar secret com as credenciais
gcloud secrets create <nome-do-secret> \
  --data-file=/tmp/firebase-admin.json \
  --project=<projeto>

# Dar acesso ao Cloud Run
gcloud secrets add-iam-policy-binding <nome-do-secret> \
  --member="serviceAccount:<project-number>-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=<projeto>

# Limpar arquivo temporário
rm /tmp/firebase-admin.json
```

### 5. Permissões do Cloud Build:
```bash
# Para deployment funcionar
gcloud projects add-iam-policy-binding <projeto> \
  --member="serviceAccount:<project-number>-compute@developer.gserviceaccount.com" \
  --role="roles/storage.admin"
```

## Garantias

✅ Código base = o que JÁ funciona em produção
✅ Cada cliente totalmente isolado
✅ Atualização única (core) aplicada a todos
✅ Produção intocada
✅ Testável antes de afetar qualquer cliente real

## Status Atual

### clinica-medica (concierge-health-pilot)
✅ Backend deployado: https://clinica-medica-backend-388995704994.southamerica-east1.run.app
✅ Frontend deployado: https://concierge-health-pilot.web.app
✅ KMS configurado
✅ Secret Manager configurado
✅ Todas as APIs habilitadas
