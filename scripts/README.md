# Scripts de Deploy - White-Label System

Este diretório contém scripts para deployment e configuração do sistema white-label.

## 📋 Scripts Disponíveis

### 1. `deploy-backend.sh` - Deploy do Backend
Deploy do backend de um cliente específico para Cloud Run.

**Uso:**
```bash
./scripts/deploy-backend.sh <nome-cliente>
```

**Exemplo:**
```bash
./scripts/deploy-backend.sh clinica-medica
```

**O que o script faz:**
- Lê configurações do `clientes/<nome-cliente>/backend/config.yaml`
- Configura variáveis de ambiente (KMS, Firebase, VAPID, Cloud Storage)
- Faz build da imagem Docker
- Deploya no Cloud Run

---

### 2. `deploy-frontend.sh` - Deploy do Frontend
Deploy do frontend de um cliente específico para Firebase Hosting.

**Uso:**
```bash
./scripts/deploy-frontend.sh <nome-cliente>
```

**Exemplo:**
```bash
./scripts/deploy-frontend.sh clinica-medica
```

---

### 3. `sync-cores.sh` - Sincronizar Código Core
Sincroniza alterações do backend-core e frontend-core para todos os clientes.

**Uso:**
```bash
./scripts/sync-cores.sh
```

**Quando usar:**
- Após fazer alterações no `backend-core/` ou `frontend-core/`
- Antes de fazer deploy de qualquer cliente
- Garante que todos os clientes estejam com a versão mais recente do código compartilhado

---

### 4. `get-bucket-name.sh` - Obter Nome do Bucket
Script auxiliar para descobrir o nome do bucket Cloud Storage de um projeto.

**Uso:**
```bash
./scripts/get-bucket-name.sh <gcp-project-id>
```

**Exemplo:**
```bash
./scripts/get-bucket-name.sh concierge-health-pilot
```

**Saída:**
```
✅ Buckets encontrados:

  🔥 concierge-health-pilot.firebasestorage.app  (Firebase Storage - USE ESTE)
  📦 run-sources-concierge-health-pilot-southamerica-east1

💡 Use o bucket do Firebase Storage (marcado com 🔥) no config.yaml:

cloud_storage_bucket: "concierge-health-pilot.firebasestorage.app"
```

---

## 🆕 Setup de Novo Cliente

### 📝 Resumo do Processo

**O que VOCÊ precisa fazer manualmente:**
1. ⚠️ Criar projeto Firebase/GCP (Passo 1)
2. ⚠️ Baixar credenciais Firebase (Passo 4)
3. ⚠️ Me informar o nome do bucket quando eu executar o script (Passo 3)
4. ⚠️ Me passar o caminho do arquivo de credenciais (Passo 4)

**O que EU vou executar para você:**
- ✅ Copiar estrutura do cliente
- ✅ Descobrir nome do bucket
- ✅ Criar secrets e KMS keys
- ✅ Gerar VAPID keys
- ✅ Configurar CORS no bucket
- ✅ Editar arquivos de configuração
- ✅ Fazer sync do código core
- ✅ Fazer deploy do backend e frontend

---

### Passo 1: Criar Projeto Firebase/GCP (⚠️ MANUAL)

**VOCÊ DEVE FAZER:**
1. Acesse [Firebase Console](https://console.firebase.google.com/)
2. Clique em "Add Project" / "Adicionar Projeto"
3. Dê um nome ao projeto (ex: `clinica-abc`)
4. Ative Google Analytics (opcional)
5. Aguarde a criação do projeto

**Depois que criar:**
1. No Firebase Console, vá em **Build > Firestore Database** → Crie o banco de dados
2. No Firebase Console, vá em **Build > Authentication** → Ative os métodos de login
3. No Firebase Console, vá em **Build > Storage** → Ative o Cloud Storage
4. Acesse [Google Cloud Console](https://console.cloud.google.com/)
5. Selecione o projeto recém-criado
6. Ative a API do Cloud Run (se pedir)

### Passo 2: Copiar Estrutura de Cliente (✅ AUTOMÁTICO - EU EXECUTO)

**EU VOU EXECUTAR PARA VOCÊ:**
```bash
cp -r clientes/clinica-medica clientes/<novo-cliente>
```

### Passo 3: Obter Nome do Bucket (✅ AUTOMÁTICO - EU EXECUTO)

**EU VOU EXECUTAR:**
```bash
./scripts/get-bucket-name.sh <gcp-project-id>
```

**VOCÊ VAI VER A SAÍDA** e me passar o nome do bucket (o que tem 🔥)

### Passo 4: Baixar Credenciais Firebase (⚠️ MANUAL)

**VOCÊ DEVE FAZER:**
1. No Firebase Console, vá em **Project Settings** (engrenagem) → **Service Accounts**
2. Clique em "Generate New Private Key"
3. Salve o arquivo JSON (ex: `firebase-credentials-abc.json`)
4. **ME ENVIE O CAMINHO DO ARQUIVO** (vou precisar para criar o secret)

### Passo 5: Criar Secret no GCP (✅ AUTOMÁTICO - EU EXECUTO)

**EU VOU EXECUTAR:**
```bash
gcloud secrets create firebase-admin-credentials-<nome> \
  --data-file=<caminho-que-voce-me-passar> \
  --project=<gcp-project-id>
```

### Passo 6: Criar KMS Keys (✅ AUTOMÁTICO - EU EXECUTO)

**EU VOU EXECUTAR:**
```bash
gcloud kms keyrings create <nome>-keyring --location=southamerica-east1
gcloud kms keys create <nome>-crypto-key --keyring=<nome>-keyring ...
```

### Passo 7: Gerar VAPID Keys (✅ AUTOMÁTICO - EU EXECUTO)

**EU VOU GERAR** as chaves VAPID usando ferramenta online

### Passo 8: Configurar CORS no Bucket (✅ AUTOMÁTICO - EU EXECUTO)

**EU VOU EXECUTAR:**
```bash
gcloud storage buckets update gs://<bucket> --cors-file=scripts/cors.json
gcloud storage buckets add-iam-policy-binding gs://<bucket> --member=allUsers --role=roles/storage.objectViewer
```

### Passo 9: Editar Backend config.yaml (✅ AUTOMÁTICO - EU EXECUTO)

**EU VOU EDITAR** `clientes/<novo-cliente>/backend/config.yaml` com todas as informações coletadas:
```yaml
client_name: "Nome do Cliente"
firebase_project_id: "project-id-firebase"
gcp_project_id: "project-id-gcp"
region: "southamerica-east1"
service_name: "nome-cliente-backend"
secret_name: "firebase-admin-credentials-nome"
cloud_storage_bucket: "project-id.firebasestorage.app"  # ← Use o bucket obtido no Passo 3
allow_unauthenticated: true

# VAPID keys for Web Push Notifications (geradas no Passo 7)
vapid_private_key: "CHAVE_GERADA"
vapid_public_key: "CHAVE_GERADA"
vapid_claims_email: "mailto:contato@cliente.com.br"
```

### Passo 10: Editar Frontend config.yaml (✅ AUTOMÁTICO - EU EXECUTO)

**EU VOU EDITAR** `clientes/<novo-cliente>/frontend/config.yaml`:
```yaml
client_name: "Nome do Cliente"
firebase_project_id: "project-id-firebase"
firebase_hosting_site: "nome-cliente"
backend_url: "https://nome-cliente-backend-xxx.run.app"  # ← Será atualizado após deploy
```

### Passo 11: Sincronizar Código Core (✅ AUTOMÁTICO - EU EXECUTO)

**EU VOU EXECUTAR:**
```bash
./scripts/sync-cores.sh
```

Isso copia o código mais recente do `backend-core/` e `frontend-core/` para o novo cliente.

### Passo 12: Deploy do Backend (✅ AUTOMÁTICO - EU EXECUTO)

**EU VOU EXECUTAR:**
```bash
./scripts/deploy-backend.sh <novo-cliente>
```

Isso vai:
- Fazer build da imagem Docker
- Fazer deploy no Cloud Run
- Configurar todas as variáveis de ambiente automaticamente
- Retornar a URL do backend (ex: `https://nome-cliente-backend-xxx.run.app`)

### Passo 13: Atualizar URL do Backend no Frontend (✅ AUTOMÁTICO - EU EXECUTO)

**EU VOU ATUALIZAR** o `frontend/config.yaml` com a URL real do backend que foi retornada no passo anterior.

### Passo 14: Deploy do Frontend (✅ AUTOMÁTICO - EU EXECUTO)

**EU VOU EXECUTAR:**
```bash
./scripts/deploy-frontend.sh <novo-cliente>
```

Isso vai fazer o deploy do frontend no Firebase Hosting.

---

## ⚙️ Configurações Importantes

### Cloud Storage Bucket

**Por que é necessário:**
- Upload de fotos em relatórios médicos
- Upload de imagens de perfil
- Armazenamento de documentos

**Formato do bucket:**
- Firebase cria automaticamente: `<project-id>.firebasestorage.app`
- Bucket do Cloud Run (NÃO usar): `run-sources-<project>-<region>`

**Como descobrir o bucket:**
```bash
./scripts/get-bucket-name.sh <gcp-project-id>
```

### Variáveis de Ambiente (Configuradas Automaticamente)

O script `deploy-backend.sh` configura automaticamente:

- `KMS_CRYPTO_KEY_NAME` - Chave de criptografia
- `FIREBASE_PROJECT_ID` - ID do projeto Firebase
- `SECRET_NAME` - Nome do secret com credenciais
- `CLOUD_STORAGE_BUCKET_NAME` - Bucket para upload de arquivos
- `VAPID_PRIVATE_KEY` - Chave privada para notificações
- `VAPID_PUBLIC_KEY` - Chave pública para notificações
- `VAPID_CLAIMS_EMAIL` - Email para claims VAPID

---

## 🔧 Troubleshooting

### Erro: "Bucket do Cloud Storage não configurado"

**Problema:** Variável `cloud_storage_bucket` não está no `config.yaml`

**Solução:**
1. Execute: `./scripts/get-bucket-name.sh <project-id>`
2. Adicione o bucket no `config.yaml`
3. Faça deploy novamente

### Erro: "The query requires an index"

**Problema:** Falta índice composto no Firestore

**Solução:**
1. O erro contém um link direto para criar o índice
2. Clique no link e aguarde a criação do índice (alguns minutos)
3. Teste novamente

### Erro: "Secret not found"

**Problema:** Secret do Firebase não existe ou está mal configurado

**Solução:**
```bash
gcloud secrets create firebase-admin-credentials-nome \
  --data-file=credentials.json \
  --project=<project-id>
```

---

## 📚 Documentação Adicional

- [Firebase Console](https://console.firebase.google.com/)
- [Google Cloud Console](https://console.cloud.google.com/)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Firestore Indexes](https://firebase.google.com/docs/firestore/query-data/indexing)
