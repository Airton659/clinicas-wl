# App de Gestão Clínica (Flutter)

**Atualizado em:** 2025-08-24

Este repositório contém o aplicativo móvel de **Gestão Clínica**. O app suporta três papéis principais (Admin, Enfermeiro e Técnico) e implementa fluxos de **cadastro de pacientes**, **gestão de papéis e vínculos**, **plano de cuidado** (com publicação), **diário de acompanhamento** e **checklist diário** com confirmação de leitura.

> **Observação importante:** exceto o **Admin**, é possível **criar usuários** e **promovê-los** a **Enfermeiro** ou **Técnico** pela **tela de gestão do Admin**.

---

## 🔐 Usuários de teste (ambiente de desenvolvimento)
- **Admin:** `concierge@com.br` — **senha:** `123456`
- **Enfermeiro:** `pauto@com.br` — **senha:** `123456`
- **Técnico:** `automatico@com.br` — **senha:** `123456`

As contas precisam existir no **Firebase Auth** do projeto configurado.

---

## ✅ Funcionalidades implementadas
### Autenticação e navegação
- Login via **Firebase Auth** (e-mail/senha).
- Redirecionamento por papel: **Admin** → Dashboard/Equipe; **Enfermeiro/Técnico** → Meus Pacientes.

### Dashboard (Admin)
- Contagem por papel (Pacientes, Técnicos, Enfermeiros).
- Lista de usuários com ações rápidas.

### Gestão de Usuários (Admin)
- **Cadastrar usuário** (por padrão, entra como Paciente/cliente) com dados pessoais e endereço (CEP com máscara).
- **Alterar papel** (cliente ⇄ técnico ⇄ profissional/enfermeiro).
- **Vincular Supervisor**: relacionar **Técnico** a um **Enfermeiro** supervisor.
- **Vincular Técnico(s) → Paciente** (múltiplos técnicos).
- **Vincular Enfermeiro → Paciente**.

### Detalhes do Paciente
- Abas **Plano de Cuidado** e **Diário**.
- **Plano de Cuidado** (Admin/Enfermeiro):
  - Editor com **Orientações**, **Medicações**, **Exames** e **Checklist**.
  - **Publicação**: ativa uma versão do plano e mantém histórico.
- **Confirmação de Leitura** (Técnico):
  - **Bloqueio** do **Diário** até confirmar leitura do **Plano ativo**.
  - Registro com data/hora (captura de IP em best‑effort).
- **Checklist Diário** (Técnico):
  - Instância do dia visível após a confirmação; marcação **persistente**.
- **Diário de Acompanhamento** (Técnico):
  - **Adicionar / editar / excluir** anotações.
  - **Pull‑to‑refresh** recarrega Diário, Checklist e Ficha.

### Supervisão (Admin/Enfermeiro)
- Listar técnicos vinculados.
- **Filtrar Diário por técnico**.

---

## ⚠️ Parcial / com ressalvas
- **Editor do Plano**: telas e fluxo prontos; validações avançadas e auditoria dependem do **backend**.
- **Atualização em tempo real**: hoje via **pull‑to‑refresh** (sem WebSockets).
- **Listas focadas** em “Meus Pacientes” dependem de vínculos consistentes no backend.
- **Captura de IP** na confirmação é **opcional** (sem IP não bloqueia).
- **Multi‑tenant**: `negocioId` está **fixo no código** (parametrização futura).
- **Base URL do backend** precisa apontar para o ambiente da clínica.

---

## ⛔ Ainda não implementado (backlog)
- **Pesquisa de satisfação** dos pacientes.
- **Mensagens/Notificações** (push/internas).
- **Tempo real** (WebSockets).
- **Relatórios/Exportações** e auditoria avançada.
- **Modo offline** com reenvio.
- **Configuração dinâmica** do negócio (multi‑tenant via UI).
- **I18N/L10N**.

---

## 🧪 Roteiro rápido de testes (sanity)
### Admin
1. Login → Dashboard/Equipe.
2. Cadastrar novo usuário (dados pessoais + endereço).
3. Promover papel (cliente → técnico ou profissional).
4. Vincular **Supervisor (Enfermeiro) ⇄ Técnico**.
5. Vincular **Técnicos → Paciente** e **Enfermeiro → Paciente**.
6. Abrir **Detalhes do Paciente** → **Plano** e **Diário**.
7. Criar e **publicar** um Plano (com checklist), depois **pull‑to‑refresh**.
8. **Supervisão**: listar técnicos e filtrar **Diário por técnico**.
9. Logout.

### Enfermeiro
1. Login → Meus Pacientes.
2. **Cadastrar paciente** (vincula automaticamente ao enfermeiro logado).
3. Acessar Detalhes → criar/publicar **Plano** (com checklist).
4. **Supervisão**: filtrar **Diário por técnico**.
5. Logout.

### Técnico
1. Login → Meus Pacientes (somente vinculados).
2. Abrir paciente com **Plano ativo** → **Diário bloqueado**.
3. **Confirmar Leitura** do Plano → Diário **desbloqueia**.
4. **Checklist Diário**: marcar itens e validar persistência.
5. **Diário**: criar/editar/excluir anotação; **pull‑to‑refresh**.
6. Logout.

---

## 🛠️ Configuração do projeto
1. **Flutter**: versão estável recente.
2. **Firebase**:
   - Android: `google-services.json` em `android/app/`.
   - iOS (se aplicável): `GoogleService-Info.plist` em `ios/Runner/`.
3. **Backend**: ajuste a **base URL** e garanta que os endpoints esperados estejam acessíveis.
   - Serviços de API (ex.: `ApiService`) usam um `_baseUrl` e um `negocioId` **fixo** (parametrizar futuramente).

> Se o backend não estiver configurado/online, telas que dependem de dados remotos não funcionarão corretamente.

---

## 📦 Build
- **APK release** (Android):  
  ```bash
  flutter clean
  flutter pub get
  flutter build apk --release
  ```
- Saída esperada: `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🧭 Roadmap sugerido
1. Parametrizar `negocioId` + revisar `_baseUrl` (prod/hml).
2. Pesquisa de satisfação (MVP).
3. Notificações (push) e eventos críticos.
4. WebSockets/tempo real para supervisão.
5. Auditoria/relatórios.
6. Melhorias do editor de Plano (modelos e validações).

---

## 📄 Licença
Projeto para uso interno/cliente. Ajustar licença conforme contrato.

---

### Notas
- Este README substitui o boilerplate padrão do Flutter.
