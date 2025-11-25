# Clínicas White-Label

Arquitetura multi-tenant para backend + frontend de clínicas com isolamento completo por cliente.

## Estrutura

```
clinicas-wl/
├── backend-core/      # Código backend compartilhado
├── frontend-core/     # Código frontend compartilhado
├── clientes/          # Cada cliente = backend + frontend isolados
│   ├── clinica-medica/
│   └── clinica-vet/
└── scripts/           # Scripts de automação
```

## Comandos Principais

### Sincronizar código dos cores para todos os clientes
```bash
./scripts/sync-cores.sh
```

### Deploy de um cliente específico

**Backend:**
```bash
./scripts/deploy-backend.sh clinica-medica
```

**Frontend:**
```bash
./scripts/deploy-frontend.sh clinica-medica
```

**Completo (backend + frontend):**
```bash
./scripts/deploy-all.sh clinica-medica
```

## Workflow de Atualização

1. **Editar código** em `backend-core/` ou `frontend-core/`
2. **Sincronizar** para todos os clientes:
   ```bash
   ./scripts/sync-cores.sh
   ```
3. **Testar** em um cliente primeiro:
   ```bash
   ./scripts/deploy-all.sh clinica-medica
   ```
4. **Deploy nos outros** clientes se tudo funcionar

## Adicionar Novo Cliente

1. Criar estrutura de pastas:
   ```bash
   mkdir -p clientes/novo-cliente/{backend,frontend}
   ```

2. Criar `clientes/novo-cliente/backend/config.yaml`:
   ```yaml
   client_name: "Nome do Cliente"
   firebase_project_id: "projeto-firebase"
   gcp_project_id: "projeto-gcp"
   region: "southamerica-east1"
   service_name: "nome-backend-service"
   secret_name: "firebase-admin-credentials"
   allow_unauthenticated: true
   ```

3. Criar configurações do frontend (`.firebaserc`, `firebase.json`)

4. Sincronizar cores:
   ```bash
   ./scripts/sync-cores.sh
   ```

5. Deploy:
   ```bash
   ./scripts/deploy-all.sh novo-cliente
   ```

## Isolamento

Cada cliente tem:
- ✅ Backend (Cloud Run) próprio
- ✅ Frontend (Firebase Hosting) próprio
- ✅ Firebase (Auth + Firestore) próprio
- ✅ **Impossível** acessar dados de outro cliente

## Benefícios

- **Um único repositório** para gerenciar todos os clientes
- **Atualização única**: mudança no core aplica a todos
- **Testável**: testa em 1 cliente antes de aplicar nos outros
- **Escalável**: adicionar cliente = criar pasta + config + sync
