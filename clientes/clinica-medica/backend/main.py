# barbearia-backend/main.py (Versão estável com Checklist do Técnico)

from fastapi import FastAPI, Depends, HTTPException, status, Header, Path, Query, UploadFile, File, Request
from fastapi.responses import FileResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Optional, Union, Dict
import os
import schemas
import crud
import logging
from datetime import date, timedelta, datetime
from crypto_utils import decrypt_data
from database import initialize_firebase_app, get_db
from auth import (
    get_current_user_firebase, get_super_admin_user, get_current_admin_user,
    get_current_profissional_user, get_optional_current_user_firebase,
    validate_negocio_id, validate_path_negocio_id, get_paciente_autorizado,
    get_current_admin_or_profissional_user, get_current_tecnico_user,
    get_current_admin_or_tecnico_user,
    get_paciente_autorizado_anamnese, get_current_medico_user, get_relatorio_autorizado,
    get_admin_or_profissional_autorizado_paciente
)
from firebase_admin import firestore, messaging
from pydantic import BaseModel
from google.cloud import storage
from PIL import Image
from io import BytesIO
import os
import uuid
from fastapi.responses import JSONResponse

# --- Modelo para a requisição de promoção ---
class PromoteRequest(BaseModel):
    firebase_uid: str

# --- Schemas para Cloud Tasks ---
class NotificarTarefaAtrasadaRequest(BaseModel):
    tarefa_id: str
    paciente_id: str
    negocio_id: str
    criado_por_id: str
    descricao: str
    data_hora_limite: str

class NotificarTarefaAtrasadaResponse(BaseModel):
    success: bool
    message: str
    tarefa_id: str

class NotificarLembreteExameRequest(BaseModel):
    exame_id: str
    paciente_id: str
    negocio_id: str
    nome_exame: str
    data_exame: str
    horario_exame: Optional[str] = None

class NotificarLembreteExameResponse(BaseModel):
    success: bool
    message: str
    exame_id: str

# --- Configuração da Aplicação ---
app = FastAPI(
    title="API de Agendamento Multi-Tenant",
    description="Backend para múltiplos negócios de agendamento, usando Firebase e Firestore.",
    version="2.2.0" # Versão atualizada com fluxo do técnico
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permite todas as origens (ideal para desenvolvimento)
    allow_credentials=True,
    allow_methods=["*"],  # Permite todos os métodos (GET, POST, etc.)
    allow_headers=["*"],  # Permite todos os cabeçalhos
)
# --- FIM DO BLOCO ---


# Adicionar um logger para ajudar no debug
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

CLOUD_STORAGE_BUCKET_NAME_GLOBAL = os.getenv("CLOUD_STORAGE_BUCKET_NAME")


# --- Evento de Startup ---
@app.on_event("startup")
def startup_event():
    """Inicializa a conexão com o Firebase ao iniciar a aplicação."""
    initialize_firebase_app()

# --- Servir imagens de perfil ---
@app.get("/uploads/profiles/{filename}", tags=["Arquivos"])
def get_profile_image(filename: str):
    """Serve as imagens de perfil (local ou proxy do Cloud Storage)."""
    
    # Primeiro, tentar servir localmente
    file_path = os.path.join("uploads", "profiles", filename)
    if os.path.exists(file_path):
        return FileResponse(file_path)
    
    # Se não existir localmente, tentar buscar no Cloud Storage
    try:
        from google.cloud import storage
        
        bucket_name = os.getenv('CLOUD_STORAGE_BUCKET_NAME', 'barbearia-app-fotoss')
        client = storage.Client()
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(f"profiles/{filename}")
        
        if blob.exists():
            # Redirecionar para a URL pública do Cloud Storage
            return RedirectResponse(url=blob.public_url)
    
    except Exception as e:
        logger.warning(f"Erro ao tentar buscar imagem no Cloud Storage: {e}")
    
    # Se não encontrou nem localmente nem no Cloud Storage
    raise HTTPException(status_code=404, detail="Imagem não encontrada")

# --- Endpoint Raiz ---
@app.get("/")
def root():
    return {"mensagem": "API de Agendamento Multi-Tenant funcionando", "versao": "2.2.0-FINAL"}

# =================================================================================
# ENDPOINTS DE ADMINISTRAÇÃO DA PLATAFORMA (SUPER-ADMIN)
# =================================================================================

@app.post("/admin/negocios", response_model=schemas.NegocioResponse, tags=["Admin - Plataforma"])
def admin_criar_negocio(
    negocio_data: schemas.NegocioCreate,
    admin: schemas.UsuarioProfile = Depends(get_super_admin_user),
    db: firestore.client = Depends(get_db)
):
    """
    (Super-Admin) Cria um novo negócio na plataforma e retorna os dados,
    incluindo o código de convite para o dono do negócio.
    """
    return crud.admin_criar_negocio(db, negocio_data, admin.firebase_uid)

@app.get("/admin/negocios", response_model=List[schemas.NegocioResponse], tags=["Admin - Plataforma"])
def admin_listar_negocios(
    admin: schemas.UsuarioProfile = Depends(get_super_admin_user),
    db: firestore.client = Depends(get_db)
):
    """(Super-Admin) Lista todos os negócios cadastrados na plataforma."""
    return crud.admin_listar_negocios(db)

# =================================================================================
# ENDPOINTS DE GERENCIAMENTO DO NEGÓCIO (ADMIN DE NEGÓCIO)
# =================================================================================

@app.get("/negocios/{negocio_id}/usuarios", response_model=List[schemas.UsuarioProfile], tags=["Admin - Gestão do Negócio"])
def listar_usuarios_do_negocio(
    negocio_id: str = Depends(validate_path_negocio_id),
    status: str = Query('ativo', description="Filtre por status: 'ativo', 'inativo' ou 'all'."),
    # ***** A CORREÇÃO ESTÁ AQUI *****
    current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin ou Enfermeiro) Lista todos os usuários (clientes, técnicos e profissionais) do negócio."""
    return crud.admin_listar_usuarios_por_negocio(db, negocio_id, status)

@app.get("/negocios/{negocio_id}/clientes", response_model=List[schemas.UsuarioProfile], tags=["Admin - Gestão do Negócio"])
def listar_clientes_do_negocio(
    negocio_id: str = Depends(validate_path_negocio_id),
    status: str = Query('ativo', description="Filtre por status: 'ativo' ou 'arquivado'."),
    admin: schemas.UsuarioProfile = Depends(get_current_admin_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin de Negócio) Lista todos os usuários com o papel de 'cliente' no seu negócio."""
    return crud.admin_listar_clientes_por_negocio(db, negocio_id, status)

# @app.patch("/negocios/{negocio_id}/pacientes/{paciente_id}/status", response_model=schemas.UsuarioProfile, tags=["Admin - Gestão do Negócio"])
# def set_paciente_status(
#     paciente_id: str,
#     status_update: schemas.StatusUpdateRequest,
#     negocio_id: str = Depends(validate_path_negocio_id),
#     admin: schemas.UsuarioProfile = Depends(get_current_admin_user),
#     db: firestore.client = Depends(get_db)
# ):
#     """(Admin de Negócio) Define o status de um paciente como 'ativo' ou 'arquivado'."""
#     try:
#         paciente_atualizado = crud.admin_set_paciente_status(
#             db, negocio_id, paciente_id, status_update.status, admin.firebase_uid
#         )
#         if not paciente_atualizado:
#             raise HTTPException(status_code=404, detail="Paciente não encontrado.")
#         return paciente_atualizado
#     except ValueError as e:
#         raise HTTPException(status_code=400, detail=str(e))

@app.patch("/negocios/{negocio_id}/usuarios/{user_id}/status", response_model=schemas.UsuarioProfile, tags=["Admin - Gestão do Negócio"])
def set_usuario_status(
    user_id: str,
    status_update: schemas.StatusUpdateRequest,
    negocio_id: str = Depends(validate_path_negocio_id),
    admin: schemas.UsuarioProfile = Depends(get_current_admin_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin de Negócio) Define o status de um usuário como 'ativo' ou 'inativo'."""
    try:
        usuario_atualizado = crud.admin_set_usuario_status(
            db, negocio_id, user_id, status_update.status, admin.firebase_uid
        )
        if not usuario_atualizado:
            raise HTTPException(status_code=404, detail="Usuário não encontrado.")
        return usuario_atualizado
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/negocios/{negocio_id}/pacientes", response_model=schemas.UsuarioProfile, tags=["Admin - Gestão do Negócio"])
def criar_paciente_por_admin(
    paciente_data: schemas.PacienteCreateByAdmin,
    negocio_id: str = Depends(validate_path_negocio_id),
    current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin de Negócio ou Enfermeiro) Cria um novo paciente, registrando-o no sistema."""
    try:
        logger.info(f"🔍 DEBUG criar_paciente - negocio_id: {negocio_id}, data: {paciente_data.dict()}")
        novo_paciente = crud.admin_criar_paciente(db, negocio_id, paciente_data)
        logger.info(f"✅ Paciente criado com sucesso: {novo_paciente.get('id', 'ID não disponível')}")
        return novo_paciente
    except ValueError as e:
        logger.error(f"❌ ValueError ao criar paciente: {str(e)}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        logger.error(f"❌ Erro inesperado ao criar paciente: {e}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Ocorreu um erro interno no servidor.")

@app.patch("/negocios/{negocio_id}/usuarios/{user_id}/role", response_model=schemas.UsuarioProfile, tags=["Admin - Gestão do Negócio"])
def atualizar_role_usuario(
    user_id: str,
    role_update: schemas.RoleUpdateRequest,
    negocio_id: str = Depends(validate_path_negocio_id),
    admin: schemas.UsuarioProfile = Depends(get_current_admin_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin de Negócio) Atualiza o papel de um usuário (para 'cliente', 'profissional', 'tecnico', etc.)."""
    try:
        usuario_atualizado = crud.admin_atualizar_role_usuario(
            db, negocio_id, user_id, role_update.role, admin.firebase_uid
        )
        if not usuario_atualizado:
            raise HTTPException(status_code=404, detail="Usuário não encontrado ou não pertence a este negócio.")
        return usuario_atualizado
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/negocios/{negocio_id}/medicos", response_model=schemas.MedicoResponse, tags=["Admin - Gestão do Negócio"])
def criar_medico(
    medico_data: schemas.MedicoBase,
    negocio_id: str = Depends(validate_path_negocio_id),
    admin: schemas.UsuarioProfile = Depends(get_current_admin_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin de Negócio) Cadastra um novo médico de referência para a clínica."""
    medico_data.negocio_id = negocio_id
    return crud.criar_medico(db, medico_data)

@app.get("/negocios/{negocio_id}/medicos", response_model=List[schemas.MedicoResponse], tags=["Admin - Gestão do Negócio"])
def listar_medicos(
    negocio_id: str = Depends(validate_path_negocio_id),
    admin: schemas.UsuarioProfile = Depends(get_current_admin_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin de Negócio) Lista todos os médicos de referência da clínica."""
    return crud.listar_medicos_por_negocio(db, negocio_id)

@app.patch("/negocios/{negocio_id}/medicos/{medico_id}", response_model=schemas.MedicoResponse, tags=["Admin - Gestão do Negócio"])
def update_medico_endpoint(
    medico_id: str,
    update_data: schemas.MedicoUpdate,
    negocio_id: str = Depends(validate_path_negocio_id),
    admin: schemas.UsuarioProfile = Depends(get_current_admin_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin de Negócio) Atualiza os dados de um médico de referência."""
    medico_atualizado = crud.update_medico(db, negocio_id, medico_id, update_data)
    if not medico_atualizado:
        raise HTTPException(status_code=404, detail="Médico não encontrado ou não pertence a este negócio.")
    return medico_atualizado

@app.delete("/negocios/{negocio_id}/medicos/{medico_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Admin - Gestão do Negócio"])
def delete_medico_endpoint(
    medico_id: str,
    negocio_id: str = Depends(validate_path_negocio_id),
    admin: schemas.UsuarioProfile = Depends(get_current_admin_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin de Negócio) Deleta um médico de referência."""
    if not crud.delete_medico(db, negocio_id, medico_id):
        raise HTTPException(status_code=404, detail="Médico não encontrado ou não pertence a este negócio.")
    return

# @app.post("/negocios/{negocio_id}/vincular-paciente", response_model=schemas.UsuarioProfile, tags=["Admin - Gestão do Negócio"])
# def vincular_paciente(
#     vinculo_data: schemas.VinculoCreate,
#     negocio_id: str = Depends(validate_path_negocio_id),
#     current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
#     db: firestore.client = Depends(get_db)
# ):
#     """(Admin de Negócio ou Enfermeiro) Vincula um paciente a um enfermeiro."""
#     paciente_atualizado = crud.vincular_paciente_enfermeiro(
#         db,
#         negocio_id=negocio_id,
#         paciente_id=vinculo_data.paciente_id,
#         enfermeiro_id=vinculo_data.enfermeiro_id,
#         autor_uid=current_user.firebase_uid
#     )
#     if not paciente_atualizado:
#         raise HTTPException(status_code=404, detail="Paciente ou enfermeiro não encontrado.")
#     return paciente_atualizado

@app.post("/negocios/{negocio_id}/vincular-paciente", response_model=schemas.UsuarioProfile, tags=["Admin - Gestão do Negócio"])
def vincular_ou_desvincular_paciente( # Nome alterado para clareza
    vinculo_data: schemas.VinculoCreate,
    negocio_id: str = Depends(validate_path_negocio_id),
    current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin ou Enfermeiro) Vincula um paciente a um enfermeiro ou desvincula ao enviar 'enfermeiro_id' como null."""
    paciente_atualizado = crud.vincular_paciente_enfermeiro(
        db,
        negocio_id=negocio_id,
        paciente_id=vinculo_data.paciente_id,
        enfermeiro_id=vinculo_data.enfermeiro_id, # pode ser null
        autor_uid=current_user.firebase_uid
    )
    if not paciente_atualizado:
        raise HTTPException(status_code=404, detail="Paciente ou enfermeiro não encontrado.")
    return paciente_atualizado

@app.delete("/negocios/{negocio_id}/vincular-paciente", response_model=schemas.UsuarioProfile, tags=["Admin - Gestão do Negócio"])
def desvincular_paciente(
    vinculo_data: schemas.VinculoCreate,
    negocio_id: str = Depends(validate_path_negocio_id),
    admin: schemas.UsuarioProfile = Depends(get_current_admin_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin de Negócio) Desvincula um paciente de seu enfermeiro."""
    paciente_atualizado = crud.desvincular_paciente_enfermeiro(
        db,
        negocio_id=negocio_id,
        paciente_id=vinculo_data.paciente_id,
        autor_uid=admin.firebase_uid
    )
    if not paciente_atualizado:
        raise HTTPException(status_code=404, detail="Paciente não encontrado.")
    return paciente_atualizado

@app.patch("/negocios/{negocio_id}/pacientes/{paciente_id}/vincular-tecnicos", response_model=schemas.UsuarioProfile, tags=["Admin - Gestão do Negócio"])
def vincular_tecnicos_ao_paciente(
    negocio_id: str = Depends(validate_path_negocio_id),
    paciente_id: str = Path(..., description="ID do paciente a ser modificado."),
    vinculo_data: schemas.TecnicosVincularRequest = ...,
    admin: schemas.UsuarioProfile = Depends(get_current_admin_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin de Negócio) Vincula ou atualiza a lista de técnicos associados a um paciente."""
    try:
        paciente_atualizado = crud.vincular_tecnicos_paciente(
            db, paciente_id, vinculo_data.tecnicos_ids, admin.firebase_uid
        )
        if not paciente_atualizado:
            raise HTTPException(status_code=404, detail="Paciente não encontrado.")
        return paciente_atualizado
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Erro inesperado ao vincular técnicos: {e}")
        raise HTTPException(status_code=500, detail="Ocorreu um erro interno no servidor.")

@app.post("/negocios/{negocio_id}/pacientes/{paciente_id}/vincular-medico", response_model=schemas.UsuarioProfile, tags=["Admin - Gestão do Negócio"])
def vincular_medico_ao_paciente(
    negocio_id: str = Depends(validate_path_negocio_id),
    paciente_id: str = Path(..., description="ID do paciente a ser modificado."),
    vinculo_data: schemas.MedicoVincularRequest = ...,
    admin_or_profissional: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin ou Enfermeiro) Vincula ou desvincula um médico de um paciente."""
    try:
        paciente_atualizado = crud.vincular_paciente_medico(
            db, negocio_id, paciente_id, vinculo_data.medico_id, admin_or_profissional.firebase_uid
        )
        if not paciente_atualizado:
            raise HTTPException(status_code=404, detail="Paciente não encontrado.")
        return paciente_atualizado
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Erro inesperado ao vincular médico: {e}")
        raise HTTPException(status_code=500, detail="Ocorreu um erro interno no servidor.")

# @app.patch("/negocios/{negocio_id}/usuarios/{tecnico_id}/vincular-supervisor", response_model=schemas.UsuarioProfile, tags=["Admin - Gestão do Negócio"])
# def vincular_supervisor_ao_tecnico(
#     negocio_id: str = Depends(validate_path_negocio_id),
#     tecnico_id: str = Path(..., description="ID do usuário (documento) do técnico a ser modificado."),
#     vinculo_data: schemas.SupervisorVincularRequest = ...,
#     admin: schemas.UsuarioProfile = Depends(get_current_admin_user),
#     db: firestore.client = Depends(get_db)
# ):
#     """(Admin de Negócio) Vincula um enfermeiro supervisor a um técnico."""
#     try:
#         tecnico_atualizado = crud.vincular_supervisor_tecnico(
#             db, tecnico_id, vinculo_data.supervisor_id, admin.firebase_uid
#         )
#         if not tecnico_atualizado:
#             raise HTTPException(status_code=404, detail="Técnico ou supervisor não encontrado.")
#         return tecnico_atualizado
#     except ValueError as e:
#         raise HTTPException(status_code=400, detail=str(e))
#     except Exception as e:
#         logger.error(f"Erro inesperado ao vincular supervisor: {e}")
#         raise HTTPException(status_code=500, detail="Ocorreu um erro interno no servidor.")

@app.patch("/negocios/{negocio_id}/usuarios/{tecnico_id}/vincular-supervisor", response_model=schemas.UsuarioProfile, tags=["Admin - Gestão do Negócio"])
def vincular_ou_desvincular_supervisor( # Nome alterado para clareza
    negocio_id: str = Depends(validate_path_negocio_id),
    tecnico_id: str = Path(..., description="ID do usuário (documento) do técnico."),
    vinculo_data: schemas.SupervisorVincularRequest = ...,
    admin: schemas.UsuarioProfile = Depends(get_current_admin_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin de Negócio) Vincula um supervisor a um técnico ou desvincula ao enviar 'supervisor_id' como null."""
    try:
        tecnico_atualizado = crud.vincular_supervisor_tecnico(
            db, tecnico_id, vinculo_data.supervisor_id, admin.firebase_uid # pode ser null
        )
        if not tecnico_atualizado:
            raise HTTPException(status_code=404, detail="Técnico ou supervisor não encontrado.")
        return tecnico_atualizado
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# =================================================================================
# ENDPOINTS DA FICHA DO PACIENTE (Módulo Clínico)
# =================================================================================

@app.post("/pacientes/{paciente_id}/consultas", response_model=schemas.ConsultaResponse, status_code=status.HTTP_201_CREATED, tags=["Ficha do Paciente"])
def adicionar_consulta(
    paciente_id: str,
    consulta_data: schemas.ConsultaCreate,
    current_user: schemas.UsuarioProfile = Depends(get_admin_or_profissional_autorizado_paciente),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Adiciona uma nova consulta à ficha do paciente."""
    consulta_data.paciente_id = paciente_id
    return crud.criar_consulta(db, consulta_data)

@app.post("/pacientes/{paciente_id}/exames", response_model=schemas.ExameResponse, status_code=status.HTTP_201_CREATED, tags=["Ficha do Paciente"])
def adicionar_exame(
    paciente_id: str,
    exame_data: schemas.ExameCreate,
    # ***** A CORREÇÃO ESTÁ AQUI *****
    # negocio_id agora vem do Header, como no PUT e DELETE
    negocio_id: str = Depends(validate_negocio_id),
    current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin ou Enfermeiro) Adiciona um novo exame à ficha do paciente."""
    # Cria um objeto completo com os dados do body + os da rota/header
    exame_data_completo = schemas.ExameBase(
        **exame_data.model_dump(),
        paciente_id=paciente_id,
        negocio_id=negocio_id
    )
    return crud.adicionar_exame(db, exame_data_completo, current_user.firebase_uid)

@app.post("/pacientes/{paciente_id}/medicacoes", response_model=schemas.MedicacaoResponse, status_code=status.HTTP_201_CREATED, tags=["Ficha do Paciente"])
def adicionar_medicacao(
    paciente_id: str,
    medicacao_data: schemas.MedicacaoCreate,
    consulta_id: Optional[str] = Query(None, description="ID da consulta (query param ou body)"),
    current_user: schemas.UsuarioProfile = Depends(get_admin_or_profissional_autorizado_paciente),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Adiciona uma nova medicação à ficha do paciente."""
    medicacao_data.paciente_id = paciente_id

    # Prioriza query param, depois body, depois última consulta
    final_consulta_id = consulta_id or medicacao_data.consulta_id

    # Se consulta_id não foi enviado, usa a consulta mais recente
    if not final_consulta_id:
        consultas = crud.listar_consultas(db, paciente_id)
        if not consultas:
            raise HTTPException(status_code=400, detail="Paciente não possui consultas. Crie uma consulta primeiro.")
        final_consulta_id = consultas[0]['id']

    return crud.prescrever_medicacao(db, medicacao_data, final_consulta_id)

@app.post("/pacientes/{paciente_id}/checklist-itens", response_model=schemas.ChecklistItemResponse, status_code=status.HTTP_201_CREATED, tags=["Ficha do Paciente"])
def adicionar_checklist_item(
    paciente_id: str,
    item_data: schemas.ChecklistItemCreate,
    consulta_id: Optional[str] = Query(None, description="ID da consulta (query param ou body)"),
    current_user: schemas.UsuarioProfile = Depends(get_admin_or_profissional_autorizado_paciente),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Adiciona um novo item ao checklist do paciente."""
    item_data.paciente_id = paciente_id

    # Prioriza query param, depois body, depois última consulta
    final_consulta_id = consulta_id or item_data.consulta_id

    # Se consulta_id não foi enviado, usa a consulta mais recente
    if not final_consulta_id:
        consultas = crud.listar_consultas(db, paciente_id)
        if not consultas:
            raise HTTPException(status_code=400, detail="Paciente não possui consultas. Crie uma consulta primeiro.")
        final_consulta_id = consultas[0]['id']

    return crud.adicionar_item_checklist(db, item_data, final_consulta_id)

@app.post("/pacientes/{paciente_id}/orientacoes", response_model=schemas.OrientacaoResponse, status_code=status.HTTP_201_CREATED, tags=["Ficha do Paciente"])
def adicionar_orientacao(
    paciente_id: str,
    orientacao_data: schemas.OrientacaoCreate,
    consulta_id: Optional[str] = Query(None, description="ID da consulta (query param ou body)"),
    current_user: schemas.UsuarioProfile = Depends(get_admin_or_profissional_autorizado_paciente),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Adiciona uma nova orientação à ficha do paciente."""
    orientacao_data.paciente_id = paciente_id

    # Prioriza query param, depois body, depois última consulta
    final_consulta_id = consulta_id or orientacao_data.consulta_id

    # Se consulta_id não foi enviado, usa a consulta mais recente
    if not final_consulta_id:
        consultas = crud.listar_consultas(db, paciente_id)
        if not consultas:
            raise HTTPException(status_code=400, detail="Paciente não possui consultas. Crie uma consulta primeiro.")
        final_consulta_id = consultas[0]['id']

    return crud.criar_orientacao(db, orientacao_data, final_consulta_id)

@app.get("/pacientes/{paciente_id}/ficha-completa", response_model=schemas.FichaCompletaResponse, tags=["Ficha do Paciente"])
def get_ficha_completa(
    paciente_id: str,
    consulta_id: Optional[str] = Query(None, description="Opcional: força o retorno da consulta informada."),
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Retorna a ficha clínica do paciente (sem os exames)."""
    if consulta_id:
        return {
            "consultas": crud.listar_consultas(db, paciente_id),
            "medicacoes": crud.listar_medicacoes(db, paciente_id, consulta_id),
            "checklist": crud._dedup_checklist_items(crud.listar_checklist(db, paciente_id, consulta_id)),
            "orientacoes": crud.listar_orientacoes(db, paciente_id, consulta_id),
        }
    return crud.get_ficha_completa_paciente(db, paciente_id)

@app.get("/pacientes/{paciente_id}/consultas", response_model=List[schemas.ConsultaResponse], tags=["Ficha do Paciente"])
def get_consultas(
    paciente_id: str,
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Lista as consultas da ficha do paciente."""
    return crud.listar_consultas(db, paciente_id)

@app.get("/pacientes/{paciente_id}/exames", response_model=List[schemas.ExameResponse], tags=["Ficha do Paciente"])
def get_exames(
    paciente_id: str,
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Lista TODOS os exames da ficha do paciente."""
    # O filtro por 'consulta_id' foi removido
    return crud.listar_exames(db, paciente_id)

@app.put("/pacientes/{paciente_id}/exames/{exame_id}", response_model=schemas.ExameResponse, tags=["Ficha do Paciente"])
def update_exame(
    paciente_id: str,
    exame_id: str,
    update_data: schemas.ExameUpdate,
    negocio_id: str = Depends(validate_negocio_id),
    current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin ou Enfermeiro) Atualiza um exame, com verificação de permissão."""
    try:
        exame_atualizado = crud.update_exame(db, paciente_id, exame_id, update_data, current_user, negocio_id)
        if not exame_atualizado:
            raise HTTPException(status_code=404, detail="Exame não encontrado.")
        return exame_atualizado
    except HTTPException as e:
        # Re-lança a exceção de permissão vinda do CRUD
        raise e

@app.get("/pacientes/{paciente_id}/medicacoes", response_model=List[schemas.MedicacaoResponse], tags=["Ficha do Paciente"])
def get_medicacoes(
    paciente_id: str,
    consulta_id: Optional[str] = Query(None, description="Filtre as medicações por um ID de consulta específico."),
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Lista as medicações da ficha do paciente."""
    return crud.listar_medicacoes(db, paciente_id, consulta_id)

@app.get("/pacientes/{paciente_id}/checklist-itens", response_model=List[schemas.ChecklistItemResponse], tags=["Ficha do Paciente"])
def get_checklist_itens(
    paciente_id: str,
    consulta_id: Optional[str] = Query(None, description="Filtre os itens do checklist por um ID de consulta específico."),
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Lista os itens do checklist da ficha do paciente."""
    return crud.listar_checklist(db, paciente_id, consulta_id)

@app.get("/pacientes/{paciente_id}/orientacoes", response_model=List[schemas.OrientacaoResponse], tags=["Ficha do Paciente"])
def get_orientacoes(
    paciente_id: str,
    consulta_id: Optional[str] = Query(None, description="Filtre as orientações por um ID de consulta específico."),
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Lista as orientações da ficha do paciente."""
    return crud.listar_orientacoes(db, paciente_id, consulta_id)

@app.patch("/pacientes/{paciente_id}/consultas/{consulta_id}", response_model=schemas.ConsultaResponse, tags=["Ficha do Paciente"])
def update_consulta(
    paciente_id: str,
    consulta_id: str,
    update_data: schemas.ConsultaUpdate,
    current_user: schemas.UsuarioProfile = Depends(get_admin_or_profissional_autorizado_paciente),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Atualiza uma consulta na ficha do paciente."""
    consulta_atualizada = crud.update_consulta(db, paciente_id, consulta_id, update_data)
    if not consulta_atualizada:
        raise HTTPException(status_code=404, detail="Consulta não encontrada.")
    return consulta_atualizada

@app.delete("/pacientes/{paciente_id}/consultas/{consulta_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Ficha do Paciente"])
def delete_consulta(
    paciente_id: str,
    consulta_id: str,
    current_user: schemas.UsuarioProfile = Depends(get_admin_or_profissional_autorizado_paciente),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Deleta uma consulta da ficha do paciente."""
    if not crud.delete_consulta(db, paciente_id, consulta_id):
        raise HTTPException(status_code=404, detail="Consulta não encontrada.")
    return

@app.patch("/pacientes/{paciente_id}/exames/{exame_id}", response_model=schemas.ExameResponse, tags=["Ficha do Paciente"])
def update_exame(
    paciente_id: str,
    exame_id: str,
    update_data: schemas.ExameUpdate,
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Atualiza um exame na ficha do paciente."""
    exame_atualizado = crud.update_exame(db, paciente_id, exame_id, update_data)
    if not exame_atualizado:
        raise HTTPException(status_code=404, detail="Exame não encontrado.")
    return exame_atualizado

@app.delete("/pacientes/{paciente_id}/exames/{exame_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Ficha do Paciente"])
def delete_exame(
    paciente_id: str,
    exame_id: str,
    negocio_id: str = Depends(validate_negocio_id),
    current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin ou Enfermeiro) Deleta um exame, com verificação de permissão."""
    try:
        if not crud.delete_exame(db, paciente_id, exame_id, current_user, negocio_id):
            raise HTTPException(status_code=404, detail="Exame não encontrado.")
    except HTTPException as e:
        # Re-lança a exceção de permissão vinda do CRUD
        raise e
    return

@app.patch("/pacientes/{paciente_id}/medicacoes/{medicacao_id}", response_model=schemas.MedicacaoResponse, tags=["Ficha do Paciente"])
def update_medicacao(
    paciente_id: str,
    medicacao_id: str,
    update_data: schemas.MedicacaoUpdate,
    current_user: schemas.UsuarioProfile = Depends(get_admin_or_profissional_autorizado_paciente),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Atualiza uma medicação na ficha do paciente."""
    medicacao_atualizada = crud.update_medicacao(db, paciente_id, medicacao_id, update_data)
    if not medicacao_atualizada:
        raise HTTPException(status_code=404, detail="Medicação não encontrada.")
    return medicacao_atualizada

@app.delete("/pacientes/{paciente_id}/medicacoes/{medicacao_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Ficha do Paciente"])
def delete_medicacao(
    paciente_id: str,
    medicacao_id: str,
    current_user: schemas.UsuarioProfile = Depends(get_admin_or_profissional_autorizado_paciente),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Deleta uma medicação da ficha do paciente."""
    if not crud.delete_medicacao(db, paciente_id, medicacao_id):
        raise HTTPException(status_code=404, detail="Medicação não encontrada.")
    return

@app.patch("/pacientes/{paciente_id}/checklist-itens/{item_id}", response_model=schemas.ChecklistItemResponse, tags=["Ficha do Paciente"])
def update_checklist_item(
    paciente_id: str,
    item_id: str,
    update_data: schemas.ChecklistItemUpdate,
    current_user: schemas.UsuarioProfile = Depends(get_admin_or_profissional_autorizado_paciente),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Atualiza um item do checklist na ficha do paciente."""
    item_atualizado = crud.update_checklist_item(db, paciente_id, item_id, update_data)
    if not item_atualizado:
        raise HTTPException(status_code=404, detail="Item do checklist não encontrado.")
    return item_atualizado

@app.delete("/pacientes/{paciente_id}/checklist-itens/{item_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Ficha do Paciente"])
def delete_checklist_item(
    paciente_id: str,
    item_id: str,
    current_user: schemas.UsuarioProfile = Depends(get_admin_or_profissional_autorizado_paciente),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Deleta um item do checklist da ficha do paciente."""
    if not crud.delete_checklist_item(db, paciente_id, item_id):
        raise HTTPException(status_code=404, detail="Item do checklist não encontrado.")
    return

@app.patch("/pacientes/{paciente_id}/orientacoes/{orientacao_id}", response_model=schemas.OrientacaoResponse, tags=["Ficha do Paciente"])
def update_orientacao(
    paciente_id: str,
    orientacao_id: str,
    update_data: schemas.OrientacaoUpdate,
    current_user: schemas.UsuarioProfile = Depends(get_admin_or_profissional_autorizado_paciente),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Atualiza uma orientação na ficha do paciente."""
    orientacao_atualizada = crud.update_orientacao(db, paciente_id, orientacao_id, update_data)
    if not orientacao_atualizada:
        raise HTTPException(status_code=404, detail="Orientação não encontrada.")
    return orientacao_atualizada

@app.delete("/pacientes/{paciente_id}/orientacoes/{orientacao_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Ficha do Paciente"])
def delete_orientacao(
    paciente_id: str,
    orientacao_id: str,
    current_user: schemas.UsuarioProfile = Depends(get_admin_or_profissional_autorizado_paciente),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Deleta uma orientação da ficha do paciente."""
    if not crud.delete_orientacao(db, paciente_id, orientacao_id):
        raise HTTPException(status_code=404, detail="Orientação não encontrada.")
    return

# =================================================================================
# ENDPOINTS DO DIÁRIO DO TÉCNICO
# =================================================================================

@app.post("/pacientes/{paciente_id}/diario", response_model=schemas.DiarioTecnicoResponse, status_code=status.HTTP_201_CREATED, tags=["Diário do Técnico"])
def criar_registro_diario(
    paciente_id: str,
    registro_data: schemas.DiarioTecnicoCreate,
    tecnico: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Técnico) Adiciona um novo registro de acompanhamento ao diário do paciente."""
    if registro_data.negocio_id not in tecnico.roles or tecnico.roles.get(registro_data.negocio_id) != 'tecnico':
        raise HTTPException(status_code=403, detail="Acesso negado: você não é um técnico deste negócio.")
    
    leitura_confirmada_status = crud.verificar_leitura_plano_do_dia(db, paciente_id, tecnico.id, date.today())
    if not leitura_confirmada_status.get("leitura_confirmada"):
        raise HTTPException(status_code=403, detail="Leitura do Plano Ativo pendente para hoje.")
    
    registro_data.paciente_id = paciente_id
    return crud.criar_registro_diario(db, registro_data, tecnico)

@app.get("/pacientes/{paciente_id}/diario", response_model=List[schemas.DiarioTecnicoResponse], tags=["Diário do Técnico"])
def listar_registros_diario(
    paciente_id: str,
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Clínico Autorizado) Lista os registros de acompanhamento do diário do paciente, incluindo dados do técnico."""
    return crud.listar_registros_diario(db, paciente_id)

@app.patch("/pacientes/{paciente_id}/diario/{registro_id}", response_model=schemas.DiarioTecnicoResponse, tags=["Diário do Técnico"])
def update_registro_diario(
    paciente_id: str,
    registro_id: str,
    update_data: schemas.DiarioTecnicoUpdate,
    tecnico: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Técnico) Atualiza um de seus registros de acompanhamento."""
    leitura_confirmada_status = crud.verificar_leitura_plano_do_dia(db, paciente_id, tecnico.id, date.today())
    if not leitura_confirmada_status.get("leitura_confirmada"):
        raise HTTPException(status_code=403, detail="Leitura do Plano Ativo pendente para hoje.")
    
    try:
        registro_atualizado = crud.update_registro_diario(db, paciente_id, registro_id, update_data, tecnico.id)
        if not registro_atualizado:
            raise HTTPException(status_code=404, detail="Registro não encontrado.")
        return registro_atualizado
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except Exception as e:
        logger.error(f"Erro inesperado ao atualizar registro do diário: {e}")
        raise HTTPException(status_code=500, detail="Ocorreu um erro interno.")

@app.delete("/pacientes/{paciente_id}/diario/{registro_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Diário do Técnico"])
def delete_registro_diario(
    paciente_id: str,
    registro_id: str,
    tecnico: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Técnico) Deleta um de seus registros de acompanhamento."""
    try:
        if not crud.delete_registro_diario(db, paciente_id, registro_id, tecnico.id):
            raise HTTPException(status_code=404, detail="Registro não encontrado.")
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except Exception as e:
        logger.error(f"Erro inesperado ao deletar registro do diário: {e}")
        raise HTTPException(status_code=500, detail="Ocorreu um erro interno.")
    return


# =================================================================================
# ENDPOINTS DE REGISTROS DIÁRIOS ESTRUTURADOS
# =================================================================================

@app.post("/pacientes/{paciente_id}/registros", response_model=schemas.RegistroDiarioResponse, status_code=status.HTTP_201_CREATED, tags=["Registros Estruturados"])
def criar_registro_diario_estruturado_endpoint(
    paciente_id: str,
    registro_data: schemas.RegistroDiarioCreate,
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Clínico Autorizado) Adiciona um novo prontuário/registro ao diário de acompanhamento."""
    # Verifica leitura do plano APENAS se o usuário for técnico
    user_roles_values = list(current_user.roles.values())
    if "tecnico" in user_roles_values:
        leitura_confirmada_status = crud.verificar_leitura_plano_do_dia(db, paciente_id, current_user.id, date.today())
        if not leitura_confirmada_status.get("leitura_confirmada"):
            raise HTTPException(status_code=403, detail="Leitura do Plano Ativo pendente para hoje.")

    # O paciente_id já é esperado no corpo da requisição conforme o schema corrigido.
    if registro_data.paciente_id != paciente_id:
        raise HTTPException(status_code=400, detail="ID do paciente na URL e no corpo da requisição não correspondem.")

    try:
        # Extrai o texto do registro (pode vir como 'texto' ou 'conteudo.descricao')
        texto_registro = registro_data.texto if registro_data.texto else registro_data.conteudo.descricao if registro_data.conteudo else ""

        # Pega o nome do usuário atual (já vem descriptografado do Firebase)
        usuario_nome = current_user.nome if current_user.nome else "Usuário"

        # Monta objeto técnico
        tecnico_dict = {
            'id': current_user.id,
            'nome': usuario_nome,
            'email': current_user.email
        }

        # Cria prontuário com formato estruturado
        novo_prontuario = crud.criar_prontuario(
            db,
            paciente_id,
            texto_registro,
            tecnico_dict,
            registro_data.negocio_id,
            'anotacao'
        )

        # Retorna no formato esperado pelo schema
        return {
            'id': novo_prontuario['id'],
            'paciente_id': paciente_id,
            'negocio_id': novo_prontuario.get('negocio_id'),
            'tipo': novo_prontuario.get('tipo', 'anotacao'),
            'data_registro': novo_prontuario.get('data'),
            'tecnico': novo_prontuario.get('tecnico'),
            'conteudo': {
                'descricao': novo_prontuario.get('texto')
            }
        }
    except Exception as e:
        import traceback
        logger.error(f"Erro inesperado ao criar prontuário/registro: {e}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Erro ao criar registro: {str(e)}")

@app.get("/pacientes/{paciente_id}/registros", response_model=List[schemas.RegistroDiarioResponse], tags=["Registros Estruturados"])
def listar_registros_diario_estruturado_endpoint(
    paciente_id: str,
    data: Optional[date] = Query(None, description="Data para filtrar os registros (formato: AAAA-MM-DD)."),
    tipo: Optional[str] = Query(None, description="Tipo de registro para filtrar."),
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Clínico Autorizado) Lista prontuários/registros diários de um paciente no formato estruturado."""
    return crud.listar_prontuarios(db, paciente_id)

@app.patch("/pacientes/{paciente_id}/registros/{registro_id}", response_model=schemas.RegistroDiarioResponse, tags=["Registros Estruturados"])
def atualizar_registro_diario_estruturado_endpoint(
    paciente_id: str,
    registro_id: str,
    update_data: schemas.RegistroDiarioCreate,
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Clínico Autorizado) Atualiza um de seus registros diários estruturados."""
    # Verifica leitura do plano APENAS se o usuário for técnico
    user_roles_values = list(current_user.roles.values())
    if "tecnico" in user_roles_values:
        leitura_confirmada_status = crud.verificar_leitura_plano_do_dia(db, paciente_id, current_user.id, date.today())
        if not leitura_confirmada_status.get("leitura_confirmada"):
            raise HTTPException(status_code=403, detail="Leitura do Plano Ativo pendente para hoje.")

    try:
        registro_atualizado = crud.atualizar_registro_diario_estruturado(db, paciente_id, registro_id, update_data, current_user.id)
        if not registro_atualizado:
            raise HTTPException(status_code=404, detail="Registro não encontrado.")
        return registro_atualizado
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except Exception as e:
        logger.error(f"Erro inesperado ao atualizar registro estruturado: {e}")
        raise HTTPException(status_code=500, detail="Ocorreu um erro interno.")

@app.delete("/pacientes/{paciente_id}/registros/{registro_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Registros Estruturados"])
def deletar_registro_diario_estruturado_endpoint(
    paciente_id: str,
    registro_id: str,
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Clínico Autorizado) Deleta um de seus registros diários estruturados."""
    # Verifica leitura do plano APENAS se o usuário for técnico
    user_roles_values = list(current_user.roles.values())
    if "tecnico" in user_roles_values:
        leitura_confirmada_status = crud.verificar_leitura_plano_do_dia(db, paciente_id, current_user.id, date.today())
        if not leitura_confirmada_status.get("leitura_confirmada"):
            raise HTTPException(status_code=403, detail="Leitura do Plano Ativo pendente para hoje.")

    try:
        if not crud.deletar_registro_diario_estruturado(db, paciente_id, registro_id, current_user.id):
            raise HTTPException(status_code=404, detail="Registro não encontrado.")
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except Exception as e:
        logger.error(f"Erro inesperado ao deletar registro estruturado: {e}")
        raise HTTPException(status_code=500, detail="Ocorreu um erro interno.")

# =================================================================================
# ENDPOINTS DE SUPERVISÃO
# =================================================================================

@app.get("/pacientes/{paciente_id}/tecnicos-supervisionados", response_model=List[schemas.TecnicoProfileReduzido], tags=["Supervisão"])
def listar_tecnicos_supervisionados_por_paciente_endpoint(
    paciente_id: str,
    negocio_id: str = Header(..., alias="negocio-id"),
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """
    (Gestor ou Enfermeiro) Lista os técnicos vinculados a um paciente
    que estão sob a supervisão do enfermeiro logado.
    Para gestores, lista todos os técnicos vinculados ao paciente.
    """
    
    # Obtém a role do usuário a partir do dicionário roles, usando o negocio_id do Header.
    user_role = current_user.roles.get(negocio_id)
    is_admin = user_role == 'admin'
    
    if is_admin:
        # Lógica para admin ver todos os técnicos vinculados ao paciente
        paciente_doc = db.collection('usuarios').document(paciente_id).get()
        if not paciente_doc.exists:
            raise HTTPException(status_code=404, detail="Paciente não encontrado.")
        
        paciente_data = paciente_doc.to_dict()
        tecnicos_vinculados_ids = paciente_data.get('tecnicos_ids', [])
        
        tecnicos_perfil = []
        for tecnico_id in tecnicos_vinculados_ids:
            tecnico_doc = db.collection('usuarios').document(tecnico_id).get()
            if tecnico_doc.exists:
                tecnico_data = tecnico_doc.to_dict()
                
                # Descriptografa o nome do técnico
                nome_tecnico = tecnico_data.get('nome', 'Nome não disponível')
                if nome_tecnico and nome_tecnico != 'Nome não disponível':
                    try:
                        nome_tecnico = decrypt_data(nome_tecnico)
                    except Exception as e:
                        logger.error(f"Erro ao descriptografar nome do técnico {tecnico_id}: {e}")
                        nome_tecnico = "[Erro na descriptografia]"
                
                tecnicos_perfil.append(schemas.TecnicoProfileReduzido(
                    id=tecnico_doc.id,
                    nome=nome_tecnico,
                    email=tecnico_data.get('email', 'Email não disponível')
                ))
        return tecnicos_perfil
    else:
        # Se não é admin, é um enfermeiro, então aplicamos a lógica de supervisão
        if user_role not in ["profissional", "admin"]:
             raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Acesso negado: esta operação é apenas para Gestores ou Enfermeiros."
            )
        
        # O ID do enfermeiro é o ID do documento do usuário logado
        enfermeiro_id = current_user.id
        return crud.listar_tecnicos_supervisionados_por_paciente(db, paciente_id, enfermeiro_id)
    
# =================================================================================
# ENDPOINTS DE AUTOGESTÃO DO PROFISSIONAL
# =================================================================================

@app.get("/me/profissional", response_model=schemas.ProfissionalResponse, tags=["Profissional - Autogestão"])
def get_meu_perfil_profissional(
    negocio_id: str = Depends(validate_negocio_id),
    profissional_user: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Profissional) Retorna o seu próprio perfil profissional."""
    perfil = crud.buscar_profissional_por_uid(db, negocio_id, profissional_user.firebase_uid)
    if not perfil:
        raise HTTPException(status_code=404, detail="Perfil profissional não encontrado para este usuário neste negócio.")
    return perfil

@app.put("/me/profissional", response_model=schemas.ProfissionalResponse, tags=["Profissional - Autogestão"])
def update_meu_perfil_profissional(
    update_data: schemas.ProfissionalUpdate,
    negocio_id: str = Depends(validate_negocio_id),
    profissional_user: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Profissional) Atualiza o seu próprio perfil profissional."""
    perfil_atual = crud.buscar_profissional_por_uid(db, negocio_id, profissional_user.firebase_uid)
    if not perfil_atual:
        raise HTTPException(status_code=404, detail="Perfil profissional não encontrado para este usuário neste negócio.")
    
    perfil_atualizado = crud.atualizar_perfil_profissional(db, perfil_atual['id'], update_data)
    return perfil_atualizado

@app.post("/me/servicos", response_model=schemas.ServicoResponse, status_code=status.HTTP_201_CREATED, tags=["Profissional - Autogestão"])
def criar_meu_servico(
    servico_data: schemas.ServicoCreate,
    negocio_id: str = Depends(validate_negocio_id),
    profissional_user: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Profissional) Cria um novo serviço associado ao seu perfil."""
    perfil_profissional = crud.buscar_profissional_por_uid(db, negocio_id, profissional_user.firebase_uid)
    if not perfil_profissional:
        raise HTTPException(status_code=404, detail="Perfil profissional não encontrado.")

    servico_data.profissional_id = perfil_profissional['id']
    servico_data.negocio_id = negocio_id
    
    return crud.criar_servico(db, servico_data)

@app.get("/me/servicos", response_model=List[schemas.ServicoResponse], tags=["Profissional - Autogestão"])
def listar_meus_servicos(
    negocio_id: str = Depends(validate_negocio_id),
    profissional_user: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Profissional) Lista todos os serviços associados ao seu perfil."""
    perfil_profissional = crud.buscar_profissional_por_uid(db, negocio_id, profissional_user.firebase_uid)
    if not perfil_profissional:
        raise HTTPException(status_code=404, detail="Perfil profissional não encontrado.")
        
    return crud.listar_servicos_por_profissional(db, perfil_profissional['id'])

@app.put("/me/servicos/{servico_id}", response_model=schemas.ServicoResponse, tags=["Profissional - Autogestão"])
def atualizar_meu_servico(
    servico_id: str,
    update_data: schemas.ServicoUpdate,
    negocio_id: str = Depends(validate_negocio_id),
    profissional_user: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Profissional) Atualiza um de seus serviços."""
    perfil_atual = crud.buscar_profissional_por_uid(db, negocio_id, profissional_user.firebase_uid)
    if not perfil_atual:
        raise HTTPException(status_code=404, detail="Perfil profissional não encontrado.")
    
    servico_atualizado = crud.atualizar_servico(db, servico_id, perfil_atual['id'], update_data)
    if not servico_atualizado:
        raise HTTPException(status_code=403, detail="Serviço não encontrado ou não pertence a este profissional.")
        
    return servico_atualizado

@app.delete("/me/servicos/{servico_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Profissional - Autogestão"])
def deletar_meu_servico(
    servico_id: str,
    negocio_id: str = Depends(validate_negocio_id),
    profissional_user: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Profissional) Deleta um de seus serviços."""
    perfil_profissional = crud.buscar_profissional_por_uid(db, negocio_id, profissional_user.firebase_uid)
    if not perfil_profissional:
        raise HTTPException(status_code=404, detail="Perfil profissional não encontrado.")
        
    if not crud.deletar_servico(db, servico_id, perfil_profissional['id']):
        raise HTTPException(status_code=403, detail="Serviço não encontrado ou não pertence a este profissional.")
    
    return

@app.post("/me/horarios-trabalho", response_model=List[schemas.HorarioTrabalho], tags=["Profissional - Autogestão"])
def definir_meus_horarios(
    horarios: List[schemas.HorarioTrabalho],
    negocio_id: str = Depends(validate_negocio_id),
    profissional_user: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Profissional) Define sua grade de horários de trabalho semanal."""
    perfil_profissional = crud.buscar_profissional_por_uid(db, negocio_id, profissional_user.firebase_uid)
    if not perfil_profissional:
        raise HTTPException(status_code=404, detail="Perfil profissional não encontrado.")

    return crud.definir_horarios_trabalho(db, perfil_profissional['id'], horarios)

@app.get("/me/horarios-trabalho", response_model=List[schemas.HorarioTrabalho], tags=["Profissional - Autogestão"])
def get_meus_horarios(
    negocio_id: str = Depends(validate_negocio_id),
    profissional_user: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Profissional) Lista sua grade de horários de trabalho."""
    perfil_profissional = crud.buscar_profissional_por_uid(db, negocio_id, profissional_user.firebase_uid)
    if not perfil_profissional:
        raise HTTPException(status_code=404, detail="Perfil profissional não encontrado.")

    return crud.listar_horarios_trabalho(db, perfil_profissional['id'])

@app.post("/me/bloqueios", response_model=schemas.Bloqueio, tags=["Profissional - Autogestão"])
def criar_meu_bloqueio(
    bloqueio_data: schemas.Bloqueio,
    negocio_id: str = Depends(validate_negocio_id),
    profissional_user: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Profissional) Cria um bloqueio em sua agenda."""
    perfil_profissional = crud.buscar_profissional_por_uid(db, negocio_id, profissional_user.firebase_uid)
    if not perfil_profissional:
        raise HTTPException(status_code=404, detail="Perfil profissional não encontrado.")
    
    return crud.criar_bloqueio(db, perfil_profissional['id'], bloqueio_data)

@app.delete("/me/bloqueios/{bloqueio_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Profissional - Autogestão"])
def deletar_meu_bloqueio(
    bloqueio_id: str,
    negocio_id: str = Depends(validate_negocio_id),
    profissional_user: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Profissional) Deleta um bloqueio de sua agenda."""
    perfil_profissional = crud.buscar_profissional_por_uid(db, negocio_id, profissional_user.firebase_uid)
    if not perfil_profissional:
        raise HTTPException(status_code=404, detail="Perfil profissional não encontrado.")
        
    if not crud.deletar_bloqueio(db, perfil_profissional['id'], bloqueio_id):
        raise HTTPException(status_code=404, detail="Bloqueio não encontrado.")
    
    return

@app.get("/me/pacientes", response_model=List[schemas.PacienteProfile], tags=["Profissional - Autogestão"])
def listar_meus_pacientes(
    negocio_id: str = Depends(validate_negocio_id),
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """
    (Gestor, Enfermeiro, Técnico ou Super Admin)
    Lista os pacientes. Para Gestores e Super Admin, retorna TODOS os pacientes do negócio.
    Para Enfermeiros/Técnicos, retorna apenas os pacientes vinculados.
    """
    # Super Admin tem acesso total como se fosse admin
    if current_user.roles.get("platform") == "super_admin":
        user_role = "admin"
    else:
        user_role = current_user.roles.get(negocio_id)

        # Verifica se o usuário tem permissão para acessar este endpoint
        if user_role not in ["profissional", "tecnico", "admin"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Acesso negado: seu perfil não tem permissão para visualizar pacientes."
            )

    pacientes = crud.listar_pacientes_por_profissional_ou_tecnico(db, negocio_id, current_user.id, user_role)
    return pacientes

# =================================================================================
# ENDPOINTS DE FEED E INTERAÇÕES
# =================================================================================

@app.post("/postagens", response_model=schemas.PostagemResponse, tags=["Feed e Interações"])
def criar_postagem(
    postagem_data: schemas.PostagemCreate,
    negocio_id: str = Depends(validate_negocio_id),
    profissional_user: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Profissional) Cria uma nova postagem no feed do negócio."""
    perfil_profissional = crud.buscar_profissional_por_uid(db, negocio_id, profissional_user.firebase_uid)
    if not perfil_profissional:
        raise HTTPException(status_code=404, detail="Perfil profissional não encontrado para este usuário neste negócio.")
    
    postagem_data.profissional_id = perfil_profissional['id']
    postagem_data.negocio_id = negocio_id
    
    return crud.criar_postagem(db, postagem_data, perfil_profissional)

@app.get("/feed", response_model=List[schemas.PostagemResponse], tags=["Feed e Interações"])
def get_feed(
    negocio_id: str,
    db: firestore.client = Depends(get_db),
    current_user: Optional[schemas.UsuarioProfile] = Depends(get_optional_current_user_firebase)
):
    """(Público) Retorna o feed de postagens de um negócio específico."""
    user_id = current_user.id if current_user else None
    return crud.listar_feed_por_negocio(db, negocio_id, user_id)

@app.post("/postagens/{postagem_id}/curtir", tags=["Feed e Interações"])
def curtir_postagem(
    postagem_id: str,
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """(Autenticado) Curte ou descurte uma postagem."""
    resultado = crud.toggle_curtida(db, postagem_id, current_user.id)
    return {"curtido": resultado}

@app.post("/comentarios", response_model=schemas.ComentarioResponse, tags=["Feed e Interações"])
def criar_comentario(
    comentario_data: schemas.ComentarioCreate,
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """(Autenticado) Adiciona um comentário a uma postagem."""
    return crud.criar_comentario(db, comentario_data, current_user)

@app.get("/comentarios/{postagem_id}", response_model=List[schemas.ComentarioResponse], tags=["Feed e Interações"])
def get_comentarios(
    postagem_id: str,
    db: firestore.client = Depends(get_db)
):
    """(Público) Lista todos os comentários de uma postagem."""
    return crud.listar_comentarios(db, postagem_id)

@app.delete("/postagens/{postagem_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Feed e Interações"])
def deletar_postagem(
    postagem_id: str,
    negocio_id: str = Depends(validate_negocio_id),
    profissional_user: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Profissional) Deleta uma de suas postagens."""
    perfil_profissional = crud.buscar_profissional_por_uid(db, negocio_id, profissional_user.firebase_uid)
    if not perfil_profissional:
        raise HTTPException(status_code=404, detail="Perfil profissional não encontrado.")
        
    if not crud.deletar_postagem(db, postagem_id, perfil_profissional['id']):
        raise HTTPException(status_code=403, detail="Postagem não encontrada ou não pertence a este profissional.")
    
    return

@app.delete("/comentarios/{comentario_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Feed e Interações"])
def deletar_comentario(
    comentario_id: str,
    postagem_id: str = Query(..., description="ID da postagem à qual o comentário pertence."),
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """(Autenticado) Deleta um de seus comentários."""
    if not crud.deletar_comentario(db, postagem_id, comentario_id, current_user.id):
        raise HTTPException(status_code=403, detail="Comentário não encontrado ou você não tem permissão para deletá-lo.")
        
    return

# =================================================================================
# ENDPOINTS DE AVALIAÇÕES
# =================================================================================

@app.post("/avaliacoes", response_model=schemas.AvaliacaoResponse, status_code=status.HTTP_201_CREATED, tags=["Avaliações"])
def criar_avaliacao(
    avaliacao_data: schemas.AvaliacaoCreate,
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """(Cliente) Cria uma nova avaliação para um profissional."""
    return crud.criar_avaliacao(db, avaliacao_data, current_user)

@app.get("/avaliacoes/{profissional_id}", response_model=List[schemas.AvaliacaoResponse], tags=["Avaliações"])
def listar_avaliacoes(
    profissional_id: str,
    db: firestore.client = Depends(get_db)
):
    """(Público) Lista todas as avaliações de um profissional."""
    return crud.listar_avaliacoes_por_profissional(db, profissional_id)

# =================================================================================
# ENDPOINTS DE NOTIFICAÇÕES
# =================================================================================

@app.get("/notificacoes", response_model=List[schemas.NotificacaoResponse], tags=["Notificações"])
def get_notificacoes(
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """(Autenticado) Retorna o histórico de notificações do usuário."""
    return crud.listar_notificacoes(db, current_user.id)

@app.get("/notificacoes/nao-lidas/contagem", response_model=schemas.NotificacaoContagemResponse, tags=["Notificações"])
def get_contagem_notificacoes_nao_lidas(
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """(Autenticado) Retorna o número de notificações não lidas."""
    count = crud.contar_notificacoes_nao_lidas(db, current_user.id)
    return {"count": count}

@app.post("/notificacoes/ler-todas", status_code=status.HTTP_204_NO_CONTENT, tags=["Notificações"])
def marcar_todas_como_lidas(
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """(Autenticado) Marca todas as notificações do usuário como lidas."""
    crud.marcar_todas_como_lidas(db, current_user.id)
    return

@app.post("/notificacoes/agendar", response_model=schemas.NotificacaoAgendadaResponse, tags=["Notificações"])
def agendar_notificacao_endpoint(
    notificacao_data: schemas.NotificacaoAgendadaCreate,
    negocio_id: str = Depends(validate_negocio_id),
    current_user: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Profissional/Enfermeiro) Agenda o envio de uma notificação para um paciente."""
    paciente_doc = db.collection('usuarios').document(notificacao_data.paciente_id).get()
    if not paciente_doc.exists:
        raise HTTPException(status_code=404, detail="Paciente não encontrado.")

    paciente_data = paciente_doc.to_dict()

    # Permitir acesso se for o enfermeiro vinculado OU se for admin do negócio
    is_linked_professional = paciente_data.get('enfermeiro_id') == current_user.id
    is_admin = current_user.roles.get(negocio_id) == 'admin'
    is_super_admin = current_user.roles.get("platform") == "super_admin"

    if not (is_linked_professional or is_admin or is_super_admin):
        raise HTTPException(status_code=403, detail="Acesso negado: você não está vinculado a este paciente.")
    if negocio_id not in paciente_data.get('roles', {}):
        raise HTTPException(status_code=400, detail="Paciente não pertence a este negócio.")

    notificacao_data.negocio_id = negocio_id
    agendamento = crud.agendar_notificacao(db, notificacao_data, current_user.firebase_uid)
    return agendamento

@app.post("/notificacoes/marcar-como-lida", status_code=status.HTTP_204_NO_CONTENT, tags=["Notificações"])
def marcar_como_lida(
    request: schemas.MarcarLidaRequest,
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """(Autenticado) Marca uma notificação específica como lida."""
    crud.marcar_notificacao_como_lida(db, current_user.id, request.notificacao_id)
    return

# =================================================================================
# ENDPOINTS DE USUÁRIOS E AUTENTICAÇÃO
# =================================================================================

@app.post("/users/sync-profile", response_model=schemas.UsuarioProfile, tags=["Usuários"])
def sync_user_profile(
    user_data: schemas.UsuarioSync,
    db: firestore.client = Depends(get_db)
):
    """
    Sincroniza os dados do usuário do Firebase Auth com o Firestore.
    Cria um perfil de usuário no banco de dados na primeira vez que ele faz login.
    """
    try:
        user_profile_data = crud.criar_ou_atualizar_usuario(db, user_data)
        
        # Garante que a resposta da API sempre corresponda ao schema de dados.
        # Isso corrige problemas de campos ausentes ou com valores null.
        user_profile_response = schemas.UsuarioProfile(**user_profile_data)
        
        # Adiciona o profissional_id ao perfil antes de retornar, se o perfil existir.
        if user_profile_response.roles:
            for negocio_id, role in user_profile_response.roles.items():
                if role in ['admin', 'profissional']:
                    perfil_profissional = crud.buscar_profissional_por_uid(db, negocio_id, user_profile_response.firebase_uid)
                    if perfil_profissional:
                        user_profile_response.profissional_id = perfil_profissional.get('id')
                        break
        
        return user_profile_response

    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        logger.error(f"Erro inesperado ao sincronizar perfil do usuário: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Ocorreu um erro interno no servidor.")

@app.get("/me/profile", response_model=schemas.UsuarioProfile, tags=["Usuários"])
def get_me_profile(current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase)):
    """Retorna o perfil completo do usuário autenticado."""
    return current_user

@app.put("/me/profile", response_model=schemas.UserProfileUpdateResponse, tags=["Usuários"])
def update_my_profile(
    update_data: schemas.UserProfileUpdate,
    negocio_id: str = Header(..., alias="negocio-id", description="ID do negócio"),
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """
    Atualiza o perfil do usuário autenticado.
    
    - **nome**: Nome completo (obrigatório, mínimo 2 caracteres)
    - **telefone**: Telefone com DDD (opcional, validação de formato)  
    - **endereco**: Endereço completo com CEP (opcional, validação de CEP)
    - **profile_image**: Imagem em Base64 (opcional, máximo 5MB)
    """
    try:
        logger.info(f"Atualizando perfil do usuário {current_user.id}")
        
        # Processar imagem se fornecida
        profile_image_url = None
        if update_data.profile_image:
            try:
                profile_image_url = crud.processar_imagem_base64(update_data.profile_image, current_user.id)
                if not profile_image_url:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Erro ao processar imagem. Verifique o formato Base64 e tamanho (máximo 5MB)"
                    )
            except ValueError as ve:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=str(ve)
                )
        
        # Atualizar perfil do usuário
        try:
            updated_user = crud.atualizar_perfil_usuario(db, current_user.id, negocio_id, update_data, profile_image_url)
        except ValueError as ve:
            # Erros de validação (telefone, CEP, etc.)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(ve)
            )
        
        if not updated_user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Usuário não encontrado ou não pertence ao negócio"
            )
        
        return schemas.UserProfileUpdateResponse(
            success=True,
            message="Perfil atualizado com sucesso",
            user=updated_user,
            profile_image_url=profile_image_url
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro inesperado ao atualizar perfil: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro interno do servidor"
        )

@app.post("/me/register-fcm-token", status_code=status.HTTP_200_OK, tags=["Usuários"])
def register_fcm_token_endpoint(
    request: schemas.FCMTokenUpdate,
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """Registra ou atualiza o token de notificação (FCM) para o dispositivo do usuário."""
    crud.adicionar_fcm_token(db, current_user.firebase_uid, request.fcm_token)
    return {"message": "FCM token registrado com sucesso."}

@app.post("/me/register-apns-token", status_code=status.HTTP_200_OK, tags=["Usuários"])
def register_apns_token_endpoint(
    request: schemas.APNsTokenRequest,
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """Registra ou atualiza o token de notificação APNs (Safari/iOS Web Push) para o dispositivo do usuário."""
    crud.adicionar_apns_token(db, current_user.firebase_uid, request.apns_token)
    return {"message": "APNs token registrado com sucesso."}

@app.delete("/me/remove-apns-token", status_code=status.HTTP_200_OK, tags=["Usuários"])
def remove_apns_token_endpoint(
    request: schemas.APNsTokenRequest,
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """Remove um token APNs do usuário."""
    crud.remover_apns_token(db, current_user.firebase_uid, request.apns_token)
    return {"message": "APNs token removido com sucesso."}

@app.get("/apns/status", status_code=status.HTTP_200_OK, tags=["Debug"])
def check_apns_status():
    """Verifica se o serviço APNs está configurado e funcionando."""
    from apns_service import get_apns_service

    apns_service = get_apns_service()

    if apns_service.enabled:
        return {
            "apns_habilitado": True,
            "topic": apns_service.topic,
            "sandbox": apns_service.use_sandbox,
            "mensagem": "✅ APNs está configurado e pronto para uso!"
        }
    else:
        return {
            "apns_habilitado": False,
            "topic": None,
            "sandbox": None,
            "mensagem": "❌ APNs não está configurado. Verifique as variáveis de ambiente e o arquivo .p8"
        }

@app.put("/users/update-profile", response_model=schemas.UserProfileUpdateResponse, tags=["Usuários"])
def update_user_profile(
    update_data: schemas.UserProfileUpdate,
    negocio_id: str = Header(..., alias="negocio-id", description="ID do negócio"),
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """
    Atualiza o perfil do usuário logado com validações de segurança.
    
    - **nome**: Nome completo (obrigatório, mínimo 2 caracteres)
    - **telefone**: Telefone com DDD (opcional, validação de formato)  
    - **endereco**: Endereço completo com CEP (opcional, validação de CEP)
    - **profile_image**: Imagem em Base64 (opcional, máximo 5MB)
    """
    try:
        logger.info(f"Atualizando perfil do usuário {current_user.id}")
        
        # Processar imagem se fornecida
        profile_image_url = None
        if update_data.profile_image:
            try:
                profile_image_url = crud.processar_imagem_base64(update_data.profile_image, current_user.id)
                if not profile_image_url:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Erro ao processar imagem. Verifique o formato Base64 e tamanho (máximo 5MB)"
                    )
            except ValueError as ve:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=str(ve)
                )
        
        # Atualizar perfil do usuário
        try:
            updated_user = crud.atualizar_perfil_usuario(db, current_user.id, negocio_id, update_data, profile_image_url)
        except ValueError as ve:
            # Erros de validação (telefone, CEP, etc.)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(ve)
            )
        
        if not updated_user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Usuário não encontrado ou não pertence ao negócio"
            )
        
        # Montar resposta de sucesso
        user_profile = schemas.UsuarioProfile(**updated_user)
        
        response = schemas.UserProfileUpdateResponse(
            success=True,
            message="Perfil atualizado com sucesso",
            user=user_profile,
            profile_image_url=profile_image_url
        )
        
        logger.info(f"Perfil do usuário {current_user.id} atualizado com sucesso")
        return response
        
    except HTTPException:
        # Re-lançar HTTPExceptions
        raise
    except Exception as e:
        logger.error(f"Erro interno ao atualizar perfil do usuário {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro interno do servidor"
        )

@app.post("/me/solicitar-exclusao-conta", response_model=schemas.SolicitacaoExclusaoContaResponse, tags=["Usuários"])
def solicitar_exclusao_conta(
    solicitacao: schemas.SolicitacaoExclusaoContaCreate,
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """
    Solicita a exclusão da conta do usuário e todos os seus dados pessoais.

    Esta funcionalidade atende aos requisitos da LGPD (Lei Geral de Proteção de Dados).
    O usuário receberá um protocolo e prazo para efetivação da exclusão.

    - **motivo**: Motivo da solicitação (opcional)
    - **confirma_exclusao**: Confirmação obrigatória de que deseja excluir todos os dados
    """
    try:
        # Validar confirmação obrigatória
        if not solicitacao.confirma_exclusao:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="É necessário confirmar que deseja excluir a conta e todos os dados"
            )

        # Gerar protocolo único
        import uuid
        from datetime import datetime, timedelta

        protocolo = f"DEL-{datetime.now().strftime('%Y%m%d')}-{str(uuid.uuid4())[:8].upper()}"
        data_solicitacao = datetime.now()

        # Prazo de 30 dias para efetivação (conforme LGPD)
        prazo_exclusao = data_solicitacao + timedelta(days=30)

        # Salvar solicitação no banco
        solicitacao_data = {
            "usuario_id": current_user.id,
            "firebase_uid": current_user.firebase_uid,
            "email": current_user.email,
            "nome": current_user.nome,
            "protocolo": protocolo,
            "motivo": solicitacao.motivo or "Não informado",
            "data_solicitacao": data_solicitacao,
            "prazo_exclusao": prazo_exclusao,
            "status": "pendente",
            "processada": False
        }

        # Salvar na coleção de solicitações de exclusão
        db.collection("solicitacoes_exclusao").document(protocolo).set(solicitacao_data)

        logger.info(f"Solicitação de exclusão criada para usuário {current_user.id} - Protocolo: {protocolo}")

        return schemas.SolicitacaoExclusaoContaResponse(
            success=True,
            message="Solicitação de exclusão registrada com sucesso. Você receberá informações sobre o andamento do processo.",
            protocolo=protocolo,
            prazo_exclusao=f"Até {prazo_exclusao.strftime('%d/%m/%Y')} (30 dias úteis)",
            contato_suporte="Para dúvidas, entre em contato através do suporte do aplicativo"
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao processar solicitação de exclusão para usuário {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro interno do servidor ao processar solicitação"
        )

@app.get("/me/status-exclusao-conta", response_model=schemas.StatusSolicitacaoExclusaoResponse, tags=["Usuários"])
def consultar_status_exclusao_conta(
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """
    Consulta o status da solicitação de exclusão de conta do usuário.

    Retorna informações sobre a solicitação ativa, se houver.
    """
    try:
        # Buscar solicitação ativa do usuário
        solicitacoes = db.collection("solicitacoes_exclusao").where(
            "usuario_id", "==", current_user.id
        ).where(
            "status", "==", "pendente"
        ).limit(1).get()

        if not solicitacoes:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Nenhuma solicitação de exclusão ativa encontrada"
            )

        solicitacao = solicitacoes[0].to_dict()

        # Calcular dias restantes
        from datetime import datetime
        prazo_exclusao = solicitacao["prazo_exclusao"]
        if isinstance(prazo_exclusao, str):
            # Se for string, converter para datetime
            prazo_exclusao = datetime.fromisoformat(prazo_exclusao.replace('Z', '+00:00'))

        dias_restantes = max(0, (prazo_exclusao - datetime.now()).days)

        return schemas.StatusSolicitacaoExclusaoResponse(
            protocolo=solicitacao["protocolo"],
            status=solicitacao["status"],
            data_solicitacao=solicitacao["data_solicitacao"],
            prazo_exclusao=solicitacao["prazo_exclusao"],
            motivo=solicitacao.get("motivo"),
            dias_restantes=dias_restantes
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao consultar status de exclusão para usuário {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro interno do servidor"
        )

@app.get("/negocios/{negocio_id}/admin-status", tags=["Admin - Gestão do Negócio"])
def get_admin_status(
    negocio_id: str,
    db: firestore.client = Depends(get_db)
):
    """
    (Público) Verifica se um negócio já possui um administrador.
    """
    has_admin = crud.check_admin_status(db, negocio_id)
    return {"has_admin": has_admin}

# =================================================================================
# ENDPOINTS DE PROFISSIONAIS (Públicos)
# =================================================================================

@app.get("/profissionais", response_model=List[schemas.ProfissionalResponse], tags=["Profissionais"])
def listar_profissionais(
    negocio_id: str,
    db: firestore.client = Depends(get_db)
):
    """Lista todos os profissionais ativos de um negócio específico."""
    return crud.listar_profissionais_por_negocio(db, negocio_id)

# Em main.py

# Em main.py

# Em main.py

@app.get("/profissionais/{profissional_id}", response_model=schemas.ProfissionalResponse, tags=["Profissionais"])
def get_profissional_details(
    profissional_id: str,
    db: firestore.client = Depends(get_db)
):
    """Retorna os detalhes de um profissional específico, incluindo seus serviços."""
    profissional = crud.buscar_profissional_por_id(db, profissional_id)
    if not profissional:
        raise HTTPException(status_code=404, detail="Profissional não encontrado.")

    # --- INÍCIO DA CORREÇÃO ---
    # Busca os dados do usuário para enriquecer a resposta
    firebase_uid = profissional.get('usuario_uid')
    if firebase_uid:
        usuario_doc = crud.buscar_usuario_por_firebase_uid(db, firebase_uid)
        if usuario_doc:
            profissional['email'] = usuario_doc.get('email', '')
            profissional['nome'] = usuario_doc.get('nome', profissional.get('nome'))
            # Tenta buscar a imagem do usuário em diferentes campos possíveis
            user_image = (usuario_doc.get('profile_image_url') or
                         usuario_doc.get('profile_image') or
                         profissional.get('fotos', {}).get('thumbnail'))
            profissional['profile_image_url'] = user_image
        else:
            # Fallback se o usuário não for encontrado: garante que os campos existam
            profissional['email'] = ''
            prof_fallback_image = (profissional.get('fotos', {}).get('thumbnail') or
                                 profissional.get('fotos', {}).get('perfil') or
                                 profissional.get('fotos', {}).get('original'))
            profissional['profile_image_url'] = prof_fallback_image
    else:
        # Fallback se não houver firebase_uid
        profissional['email'] = ''
        prof_fallback_image = (profissional.get('fotos', {}).get('thumbnail') or
                             profissional.get('fotos', {}).get('perfil') or
                             profissional.get('fotos', {}).get('original'))
        profissional['profile_image_url'] = prof_fallback_image
    # --- FIM DA CORREÇÃO ---
    
    servicos = crud.listar_servicos_por_profissional(db, profissional_id)
    profissional['servicos'] = servicos
    
    postagens = crud.listar_postagens_por_profissional(db, profissional_id)
    profissional['postagens'] = postagens
    
    avaliacoes = crud.listar_avaliacoes_por_profissional(db, profissional_id)
    profissional['avaliacoes'] = avaliacoes
    
    # Garante que 'fotos' sempre exista para consistência
    if 'fotos' not in profissional:
        profissional['fotos'] = {}
        
    return profissional

# =================================================================================
# ENDPOINTS DE AGENDAMENTOS E DISPONIBILIDADE PÚBLICA
# =================================================================================

@app.get("/profissionais/{profissional_id}/horarios-disponiveis", tags=["Agendamentos"])
def get_horarios_disponiveis(
    profissional_id: str,
    dia: date = Query(..., description="Dia para verificar a disponibilidade (formato: AAAA-MM-DD)."),
    duracao_servico: int = Query(60, description="Duração do serviço em minutos para calcular os slots."),
    db: firestore.client = Depends(get_db)
):
    """(Público) Calcula e retorna os horários livres de um profissional em um dia específico."""
    return crud.calcular_horarios_disponiveis(db, profissional_id, dia, duracao_servico)

@app.post("/agendamentos", response_model=schemas.AgendamentoResponse, tags=["Agendamentos"])
def agendar(
    agendamento: schemas.AgendamentoCreate,
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """(Cliente) Cria um novo agendamento para o usuário autenticado."""
    try:
        novo_agendamento = crud.criar_agendamento(db, agendamento, current_user)
        return novo_agendamento
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Erro inesperado ao criar agendamento: {e}")
        raise HTTPException(status_code=500, detail="Ocorreu um erro ao criar o agendamento.")

@app.get("/agendamentos/me", response_model=List[schemas.AgendamentoResponse], tags=["Agendamentos"])
def listar_meus_agendamentos_cliente(
    negocio_id: str = Header(..., description="ID do Negócio para filtrar os agendamentos."),
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """(Cliente) Lista todos os agendamentos do cliente autenticado em um negócio específico."""
    return crud.listar_agendamentos_por_cliente(db, negocio_id, current_user.id)

@app.delete("/agendamentos/{agendamento_id}", status_code=status.HTTP_200_OK, tags=["Agendamentos"])
def cancelar_agendamento_endpoint(
    agendamento_id: str,
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """(Cliente) Permite ao cliente autenticado cancelar um de seus agendamentos."""
    agendamento_cancelado = crud.cancelar_agendamento(db, agendamento_id, current_user.id)
    
    if agendamento_cancelado is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Agendamento não encontrado ou você não tem permissão para cancelá-lo."
        )
    
    return {"message": "Agendamento cancelado com sucesso."}

@app.get("/me/agendamentos", response_model=List[schemas.AgendamentoResponse], tags=["Profissional - Autogestão"])
def listar_meus_agendamentos_profissional(
    negocio_id: str = Header(..., description="ID do Negócio no qual o profissional está atuando."),
    profissional_user: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Profissional) Lista todos os agendamentos recebidos."""
    perfil_profissional = crud.buscar_profissional_por_uid(db, negocio_id, profissional_user.firebase_uid)
    if not perfil_profissional:
        raise HTTPException(status_code=404, detail="Perfil profissional não encontrado.")
    
    return crud.listar_agendamentos_por_profissional(db, negocio_id, perfil_profissional['id'])

@app.patch("/me/agendamentos/{agendamento_id}/cancelar", response_model=schemas.AgendamentoResponse, tags=["Profissional - Autogestão"])
def cancelar_agendamento_pelo_profissional_endpoint(
    agendamento_id: str,
    negocio_id: str = Header(..., description="ID do Negócio no qual o profissional está atuando."),
    profissional_user: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Profissional) Cancela um agendamento que recebeu."""
    perfil_profissional = crud.buscar_profissional_por_uid(db, negocio_id, profissional_user.firebase_uid)
    if not perfil_profissional:
        raise HTTPException(status_code=404, detail="Perfil profissional não encontrado.")
    
    agendamento_cancelado = crud.cancelar_agendamento_pelo_profissional(db, agendamento_id, perfil_profissional['id'])
    if not agendamento_cancelado:
        raise HTTPException(status_code=404, detail="Agendamento não encontrado ou não pertence a este profissional.")
        
    return agendamento_cancelado

@app.patch("/me/agendamentos/{agendamento_id}/confirmar", response_model=schemas.AgendamentoResponse, tags=["Profissional - Autogestão"])
def confirmar_agendamento_pelo_profissional_endpoint(
    agendamento_id: str,
    negocio_id: str = Header(..., description="ID do Negócio no qual o profissional está atuando."),
    profissional_user: schemas.UsuarioProfile = Depends(get_current_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Profissional) Confirma um agendamento pendente."""
    perfil_profissional = crud.buscar_profissional_por_uid(db, negocio_id, profissional_user.firebase_uid)
    if not perfil_profissional:
        raise HTTPException(status_code=404, detail="Perfil profissional não encontrado.")

    agendamento_confirmado = crud.confirmar_agendamento_pelo_profissional(db, agendamento_id, perfil_profissional['id'])
    if not agendamento_confirmado:
        raise HTTPException(status_code=404, detail="Agendamento não encontrado, não pertence a este profissional, ou não está pendente.")

    return agendamento_confirmado

# =================================================================================
# ENDPOINT DE UPLOAD DE FOTOS
# =================================================================================

async def upload_and_resize_image(
    file_content: bytes,
    filename_base: str,
    bucket_name: str,
    content_type: str
) -> dict:
    """Função auxiliar para upload e redimensionamento de imagens no Cloud Storage."""
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    urls = {}
    extension = ".jpeg"
    
    image = Image.open(BytesIO(file_content))
    if image.mode in ('RGBA', 'P'):
        image = image.convert('RGB')

    buffer_original = BytesIO()
    image.save(buffer_original, format="JPEG", quality=90)
    buffer_original.seek(0)
    original_blob_name = f"uploads/{filename_base}_original{extension}"
    original_blob = bucket.blob(original_blob_name)
    original_blob.upload_from_string(buffer_original.getvalue(), content_type="image/jpeg")
    urls['original'] = original_blob.public_url

    image.thumbnail((800, 800))
    buffer_medium = BytesIO()
    image.save(buffer_medium, format="JPEG", quality=85)
    buffer_medium.seek(0)
    medium_blob_name = f"uploads/{filename_base}_medium{extension}"
    medium_blob = bucket.blob(medium_blob_name)
    medium_blob.upload_from_string(buffer_medium.getvalue(), content_type="image/jpeg")
    urls['medium'] = medium_blob.public_url

    image.thumbnail((200, 200))
    buffer_thumbnail = BytesIO()
    image.save(buffer_thumbnail, format="JPEG", quality=80)
    buffer_thumbnail.seek(0)
    thumbnail_blob_name = f"uploads/{filename_base}_thumbnail{extension}"
    thumbnail_blob = bucket.blob(thumbnail_blob_name)
    thumbnail_blob.upload_from_string(buffer_thumbnail.getvalue(), content_type="image/jpeg")
    urls['thumbnail'] = thumbnail_blob.public_url

    return urls

@app.post("/upload-foto", tags=["Utilitários"])
async def upload_foto(
    file: UploadFile = File(...),
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase)
):
    """(Autenticado) Faz o upload de uma foto, redimensiona e retorna as URLs."""
    if not CLOUD_STORAGE_BUCKET_NAME_GLOBAL:
        raise HTTPException(status_code=500, detail="Bucket do Cloud Storage não configurado.")
    
    try:
        file_content = await file.read()
        filename_base = f"{uuid.uuid4()}-{os.path.splitext(file.filename)[0]}"
        
        uploaded_urls = await upload_and_resize_image(
            file_content=file_content,
            filename_base=filename_base,
            bucket_name=CLOUD_STORAGE_BUCKET_NAME_GLOBAL,
            content_type=file.content_type
        )
        return JSONResponse(content=uploaded_urls)
    except Exception as e:
        logger.error(f"ERRO CRÍTICO NO UPLOAD: {e}")
        raise HTTPException(status_code=500, detail=f"Ocorreu um erro interno no servidor: {e}")

# =================================================================================
# FUNÇÃO AUXILIAR PARA UPLOAD DE ARQUIVOS GENÉRICOS
# =================================================================================

async def upload_generic_file(
    file_content: bytes,
    filename: str,
    bucket_name: str,
    content_type: str
) -> str:
    """Função auxiliar para upload de arquivos genéricos no Cloud Storage."""
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    
    unique_filename = f"uploads/anexos/{uuid.uuid4()}-{filename}"
    
    blob = bucket.blob(unique_filename)
    blob.upload_from_string(file_content, content_type=content_type)
    
    return blob.public_url

# =================================================================================
# ENDPOINT DE UPLOAD GENÉRICO
# =================================================================================

@app.post("/upload-file", tags=["Utilitários"])
async def upload_file_endpoint(
    file: UploadFile = File(...),
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase)
):
    """(Autenticado) Faz o upload de um arquivo genérico (PDF, DOCX, etc.) e retorna a URL."""
    if not CLOUD_STORAGE_BUCKET_NAME_GLOBAL:
        raise HTTPException(status_code=500, detail="Bucket do Cloud Storage não configurado.")
    
    try:
        file_content = await file.read()
        
        uploaded_url = await upload_generic_file(
            file_content=file_content,
            filename=file.filename,
            bucket_name=CLOUD_STORAGE_BUCKET_NAME_GLOBAL,
            content_type=file.content_type
        )
        return JSONResponse(content={"url": uploaded_url})
    except Exception as e:
        logger.error(f"ERRO CRÍTICO NO UPLOAD DE ARQUIVO: {e}")
        raise HTTPException(status_code=500, detail=f"Ocorreu um erro interno no servidor: {e}")

# =================================================================================
# ENDPOINTS DA PESQUISA DE SATISFAÇÃO
# =================================================================================

@app.post("/negocios/{negocio_id}/pesquisas/enviar", response_model=schemas.PesquisaEnviadaResponse, tags=["Pesquisa de Satisfação"])
def enviar_pesquisa(
    negocio_id: str,
    envio_data: schemas.PesquisaEnviadaCreate,
    admin: schemas.UsuarioProfile = Depends(get_current_admin_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin) Envia uma pesquisa de satisfação para um paciente."""
    envio_data.negocio_id = negocio_id
    return crud.enviar_pesquisa_satisfacao(db, envio_data)

@app.get("/me/pesquisas", response_model=List[schemas.PesquisaEnviadaResponse], tags=["Pesquisa de Satisfação"])
def listar_minhas_pesquisas(
    negocio_id: str = Header(..., description="ID do Negócio para filtrar as pesquisas."),
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """(Paciente) Lista todas as pesquisas de satisfação recebidas."""
    return crud.listar_pesquisas_por_paciente(db, negocio_id, current_user.id)

@app.post("/me/pesquisas/{pesquisa_id}/submeter", response_model=schemas.PesquisaEnviadaResponse, tags=["Pesquisa de Satisfação"])
def submeter_respostas(
    pesquisa_id: str,
    respostas_data: schemas.SubmeterPesquisaRequest,
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """(Paciente) Submete as respostas para uma pesquisa de satisfação."""
    pesquisa_atualizada = crud.submeter_respostas_pesquisa(db, pesquisa_id, respostas_data, current_user.id)
    if not pesquisa_atualizada:
        raise HTTPException(status_code=404, detail="Pesquisa não encontrada ou não pertence a este paciente.")
    return pesquisa_atualizada

@app.get("/negocios/{negocio_id}/pesquisas/resultados", response_model=List[schemas.PesquisaEnviadaResponse], tags=["Pesquisa de Satisfação"])
def get_resultados_pesquisas(
    negocio_id: str,
    modelo_pesquisa_id: Optional[str] = Query(None, description="Filtre os resultados por um modelo de pesquisa específico."),
    admin: schemas.UsuarioProfile = Depends(get_current_admin_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin) Lista todos os resultados das pesquisas de satisfação respondidas."""
    return crud.listar_resultados_pesquisas(db, negocio_id, modelo_pesquisa_id)


# Em main.py

# =================================================================================
# ENDPOINTS DE TAREFAS ESSENCIAIS (PLANO DE AÇÃO)
# =================================================================================

@app.post("/pacientes/{paciente_id}/tarefas", response_model=schemas.TarefaAgendadaResponse, tags=["Tarefas Essenciais"])
def criar_tarefa_essencial(
    paciente_id: str,
    tarefa_data: schemas.TarefaAgendadaCreate,
    request: Request,
    current_user: schemas.UsuarioProfile = Depends(get_admin_or_profissional_autorizado_paciente),
    negocio_id: str = Depends(validate_negocio_id),
    db: firestore.client = Depends(get_db)
):
    """(Admin ou Enfermeiro) Cria uma nova tarefa essencial para um paciente com prazo."""
    # Obtém a URL do serviço para o Cloud Tasks
    service_url = os.getenv('CLOUD_RUN_SERVICE_URL') or str(request.base_url).rstrip('/')

    # USA A NOVA VERSÃO COM CLOUD TASKS
    nova_tarefa = crud.criar_tarefa_v2(db, paciente_id, negocio_id, tarefa_data, current_user, service_url)
    return nova_tarefa

@app.get("/pacientes/{paciente_id}/tarefas", response_model=List[schemas.TarefaAgendadaResponse], tags=["Tarefas Essenciais"])
def listar_tarefas_essenciais(
    paciente_id: str,
    status: Optional[schemas.StatusTarefaEnum] = Query(None, description="Filtre por status: 'pendente', 'concluida' ou 'atrasada'."),
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Lista as tarefas de um paciente, com filtros."""
    return crud.listar_tarefas_por_paciente(db, paciente_id, status)

@app.patch("/tarefas/{tarefa_id}/concluir", response_model=schemas.TarefaAgendadaResponse, tags=["Tarefas Essenciais"])
def concluir_tarefa_essencial(
    tarefa_id: str,
    current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_tecnico_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin/Profissional/Técnico) Marca uma tarefa como concluída."""
    # USA A NOVA VERSÃO QUE CANCELA CLOUD TASKS
    tarefa_concluida = crud.marcar_tarefa_como_concluida_v2(db, tarefa_id, current_user)
    if not tarefa_concluida:
        raise HTTPException(status_code=404, detail="Tarefa não encontrada ou já concluída.")

    return tarefa_concluida

# =================================================================================
# ENDPOINTS DO FLUXO DO TÉCNICO (BASEADO NO PDF ESTRATÉGIA)
# =================================================================================

@app.post("/pacientes/{paciente_id}/confirmar-leitura-plano", response_model=schemas.ConfirmacaoLeituraResponse, tags=["Fluxo do Técnico"])
def confirmar_leitura_plano(
    paciente_id: str,
    confirmacao: schemas.ConfirmacaoLeituraCreate,
    current_user: schemas.UsuarioProfile = Depends(get_current_tecnico_user),
    db: firestore.client = Depends(get_db)
):
    """(Técnico) Confirma a leitura do plano de cuidado, criando a trilha de auditoria."""
    if confirmacao.usuario_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acesso negado: o usuario_id deve ser o do técnico autenticado.")
    return crud.registrar_confirmacao_leitura_plano(db, paciente_id, confirmacao)

@app.get("/pacientes/{paciente_id}/verificar-leitura-plano", tags=["Fluxo do Técnico"])
def verificar_leitura_plano(
    paciente_id: str,
    data: date = Query(..., description="Data para verificar a leitura (formato: YYYY-MM-DD)."),
    current_user: schemas.UsuarioProfile = Depends(get_current_tecnico_user),
    db: firestore.client = Depends(get_db)
):
    """(Técnico) Verifica se a leitura foi confirmada para liberar as outras funções do dia."""
    leitura_confirmada = crud.verificar_leitura_plano_do_dia(db, paciente_id, current_user.id, data)
    return {"leitura_confirmada": leitura_confirmada}

@app.post("/pacientes/{paciente_id}/confirmar-leitura", response_model=schemas.ConfirmacaoLeituraResponse, tags=["Fluxo do Técnico"])
def confirmar_leitura_alias(
    paciente_id: str,
    confirmacao: schemas.ConfirmacaoLeituraCreate,
    current_user: schemas.UsuarioProfile = Depends(get_current_tecnico_user),
    db: firestore.client = Depends(get_db)
):
    """Alias: confirma a leitura do plano (mesma lógica de /confirmar-leitura-plano)."""
    if confirmacao.usuario_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acesso negado: o usuario_id deve ser o do técnico autenticado.")
    return crud.registrar_confirmacao_leitura_plano(db, paciente_id, confirmacao)

@app.get("/pacientes/{paciente_id}/confirmar-leitura/status", tags=["Fluxo do Técnico"])
def confirmar_leitura_status_alias(
    paciente_id: str,
    # A data agora é opcional e, se não for fornecida, usa a data atual.
    data: date = Query(default_factory=date.today, description="Data para verificar a leitura (padrão: hoje)."),
    current_user: schemas.UsuarioProfile = Depends(get_current_tecnico_user),
    db: firestore.client = Depends(get_db)
):
    """Alias: verifica o status de leitura (equivalente a /verificar-leitura-plano)."""
    # Esta linha agora retorna o objeto JSON completo que o app precisa.
    status_leitura = crud.verificar_leitura_plano_do_dia(db, paciente_id, current_user.id, data)
    return status_leitura

@app.get("/pacientes/{paciente_id}/checklist-diario", response_model=List[schemas.ChecklistItemDiarioResponse], tags=["Fluxo do Técnico"])
def get_checklist_diario(
    paciente_id: str,
    data: date = Query(..., description="Data do checklist (formato: YYYY-MM-DD)."),
    negocio_id: str = Header(..., alias="negocio-id", description="ID do Negócio."),
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db),
):
    """
    (Técnico, Profissional ou Admin) Retorna o checklist do dia, baseado EXCLUSIVAMENTE no plano de cuidado mais recente.
    Se o plano mais recente não tiver checklist, retorna uma lista vazia.
    Se não existir, o checklist do dia é replicado a partir do plano ativo.
    """
    # ALTERAÇÃO AQUI: Chame a nova função corrigida
    return crud.get_checklist_diario_plano_ativo(db, paciente_id, data, negocio_id)


@app.patch("/pacientes/{paciente_id}/checklist-diario/{item_id}", response_model=schemas.ChecklistItemDiarioResponse, tags=["Fluxo do Técnico"])
def update_checklist_item_diario(
    paciente_id: str,
    item_id: str,
    data: date = Query(..., description="Data do checklist (formato: YYYY-MM-DD)."),
    update_data: schemas.ChecklistItemDiarioUpdate = ...,
    current_user: schemas.UsuarioProfile = Depends(get_current_tecnico_user),
    db: firestore.client = Depends(get_db)
):
    """(Técnico) Permite marcar/desmarcar um item do checklist."""
    if not crud.verificar_leitura_plano_do_dia(db, paciente_id, current_user.id, data):
        raise HTTPException(status_code=403, detail="Leitura do Plano Ativo pendente para hoje.")
    item_atualizado = crud.atualizar_item_checklist_diario(db, paciente_id, item_id, update_data)
    if not item_atualizado:
        raise HTTPException(status_code=404, detail="Item do checklist não encontrado.")
    return item_atualizado


# =================================================================================
# 1. NOVOS ENDPOINTS: ANAMNESE
# =================================================================================

@app.post("/pacientes/{paciente_id}/anamnese", response_model=schemas.AnamneseResponse, status_code=status.HTTP_201_CREATED, tags=["Anamnese"])
def criar_anamnese(
    paciente_id: str,
    anamnese_data: schemas.AnamneseCreate,
    current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin ou Enfermeiro) Cria uma nova ficha de anamnese para um paciente."""
    return crud.criar_anamnese(db, paciente_id, anamnese_data)

@app.get("/pacientes/{paciente_id}/anamnese", response_model=List[schemas.AnamneseResponse], tags=["Anamnese"])
def listar_anamneses(
    paciente_id: str,
    # ***** A CORREÇÃO ESTÁ AQUI *****
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado_anamnese),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado, EXCETO Técnico) Lista todas as fichas de anamnese de um paciente."""
    return crud.listar_anamneses_por_paciente(db, paciente_id)

@app.put("/anamnese/{anamnese_id}", response_model=schemas.AnamneseResponse, tags=["Anamnese"])
def atualizar_anamnese(
    anamnese_id: str,
    paciente_id: str = Query(..., description="ID do paciente a quem a anamnese pertence."),
    update_data: schemas.AnamneseUpdate = ...,
    current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin ou Enfermeiro) Atualiza uma ficha de anamnese existente."""
    anamnese_atualizada = crud.atualizar_anamnese(db, anamnese_id, paciente_id, update_data)
    if not anamnese_atualizada:
        raise HTTPException(status_code=404, detail="Ficha de anamnese não encontrada.")
    return anamnese_atualizada

@app.put("/pacientes/{paciente_id}/endereco", response_model=schemas.UsuarioProfile, tags=["Pacientes"])
def atualizar_endereco_paciente_endpoint(
    paciente_id: str,
    endereco_data: schemas.EnderecoUpdate,
    current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
    db: firestore.client = Depends(get_db)
):
    paciente_atualizado = crud.atualizar_endereco_paciente(db, paciente_id, endereco_data)
    if not paciente_atualizado:
        raise HTTPException(status_code=404, detail="Paciente não encontrado.")
    return paciente_atualizado


# =================================================================================
# 2. NOVO ENDPOINT: ENDEREÇO
# =================================================================================

@app.put("/pacientes/{paciente_id}/endereco", response_model=schemas.UsuarioProfile, tags=["Pacientes"])
def atualizar_endereco_paciente(
    paciente_id: str,
    endereco_data: schemas.EnderecoUpdate,
    current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin ou Enfermeiro) Adiciona ou atualiza o endereço de um paciente."""
    paciente_atualizado = crud.atualizar_endereco_paciente(db, paciente_id, endereco_data)
    if not paciente_atualizado:
        raise HTTPException(status_code=404, detail="Paciente não encontrado.")
    return paciente_atualizado

@app.put("/pacientes/{paciente_id}/dados-pessoais", response_model=schemas.PacienteProfile, tags=["Pacientes"])
def atualizar_dados_pessoais_paciente(
    paciente_id: str,
    dados_pessoais: schemas.PacienteUpdateDadosPessoais,
    current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin ou Enfermeiro) Atualiza dados pessoais básicos do paciente (migrados da anamnese)."""
    paciente_atualizado = crud.atualizar_dados_pessoais_paciente(db, paciente_id, dados_pessoais)
    if not paciente_atualizado:
        raise HTTPException(status_code=404, detail="Paciente não encontrado.")
    return paciente_atualizado
    
@app.put("/pacientes/{paciente_id}/endereco", response_model=schemas.UsuarioProfile, tags=["Pacientes"])
def atualizar_endereco_paciente(
    paciente_id: str,
    endereco_data: schemas.EnderecoUpdate,
    current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """
    (Admin ou Enfermeiro) Adiciona ou atualiza o endereço de um paciente.
    """
    paciente_atualizado = crud.atualizar_endereco_paciente(db, paciente_id, endereco_data)
    if not paciente_atualizado:
        raise HTTPException(status_code=404, detail="Paciente não encontrado.")
    return paciente_atualizado


# =================================================================================
# ENDPOINTS DE RELATÓRIOS MÉDICOS
# =================================================================================

@app.post("/pacientes/{paciente_id}/relatorios", response_model=schemas.RelatorioMedicoResponse, status_code=status.HTTP_201_CREATED, tags=["Relatórios Médicos"])
def criar_relatorio_medico_endpoint(
    paciente_id: str,
    relatorio_data: schemas.RelatorioMedicoCreate,
    current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin ou Profissional) Cria um novo relatório médico para um paciente."""
    try:
        novo_relatorio = crud.criar_relatorio_medico(db, paciente_id, relatorio_data, current_user)
        return novo_relatorio
    except HTTPException as e:
        raise e
    except Exception as e:
        logger.error(f"Erro inesperado ao criar relatório médico: {e}")
        raise HTTPException(status_code=500, detail="Ocorreu um erro interno no servidor.")

@app.get("/pacientes/{paciente_id}/relatorios", response_model=List[schemas.RelatorioMedicoResponse], tags=["Relatórios Médicos"])
def listar_relatorios_paciente_endpoint(
    paciente_id: str,
    negocio_id: str = Depends(validate_negocio_id), # 1. Pega e valida o negocio_id do header
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase), # 2. Pega o usuário logado
    db: firestore.client = Depends(get_db)
):
    """(Admin ou Profissional) Lista todos os relatórios médicos de um paciente."""
    # 3. Faz a verificação de permissão (role) manualmente
    user_role = current_user.roles.get(negocio_id)
    if user_role not in ["admin", "profissional"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso negado: você não tem permissão de Gestor ou Enfermeiro para esta operação."
        )
    
    # 4. Chama a sua função original do CRUD, que já funciona
    return crud.listar_relatorios_por_paciente(db, paciente_id)

# main.py

# Garanta que estas importações existam no topo do arquivo
from auth import get_current_user_firebase, validate_negocio_id

# ... (resto do arquivo)

@app.post("/relatorios/{relatorio_id}/fotos", response_model=schemas.RelatorioMedicoResponse, tags=["Relatórios Médicos"])
async def upload_foto_relatorio(
    relatorio_id: str,
    files: List[UploadFile] = File(...),
    negocio_id: str = Depends(validate_negocio_id),
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """(Admin ou Profissional) Faz upload de múltiplas fotos para um relatório médico."""
    user_role = current_user.roles.get(negocio_id)
    if user_role not in ["admin", "profissional"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso negado: você não tem permissão de Gestor ou Enfermeiro para esta operação."
        )

    if not CLOUD_STORAGE_BUCKET_NAME_GLOBAL:
        raise HTTPException(status_code=500, detail="Bucket do Cloud Storage não configurado.")
    
    try:
        uploaded_urls = []
        
        for file in files:
            file_content = await file.read()
            
            uploaded_url = await upload_generic_file(
                file_content=file_content,
                filename=file.filename,
                bucket_name=CLOUD_STORAGE_BUCKET_NAME_GLOBAL,
                content_type=file.content_type
            )
            uploaded_urls.append(uploaded_url)
        
        relatorio_atualizado = None
        for url in uploaded_urls:
            relatorio_atualizado = crud.adicionar_foto_relatorio(db, relatorio_id, url)
            if not relatorio_atualizado:
                raise HTTPException(status_code=404, detail="Relatório não encontrado após o upload.")
        
        logger.info(f"Upload concluído. Fotos={len(uploaded_urls)}")
        return relatorio_atualizado
    except Exception as e:
        logger.error(f"ERRO CRÍTICO NO UPLOAD DE FOTO PARA RELATÓRIO: {e}")
        raise HTTPException(status_code=500, detail=f"Ocorreu um erro interno no servidor: {e}")
    
@app.get("/medico/relatorios/pendentes", response_model=List[schemas.RelatorioMedicoResponse], tags=["Relatórios Médicos - Médico"])
def listar_relatorios_pendentes_medico_endpoint(
    negocio_id: str = Header(..., description="ID do Negócio no qual o médico está atuando."),
    current_user: schemas.UsuarioProfile = Depends(get_current_medico_user),
    db: firestore.client = Depends(get_db)
):
    """(Médico) Lista os relatórios pendentes de avaliação para o médico logado."""
    return crud.listar_relatorios_pendentes_medico(db, current_user.id, negocio_id)

@app.get("/medico/relatorios", response_model=List[schemas.RelatorioMedicoResponse], tags=["Relatórios Médicos - Médico"])
def listar_historico_relatorios_medico_endpoint(
    negocio_id: str = Header(..., description="ID do Negócio no qual o médico está atuando."),
    status: Optional[str] = Query(None, description="Filtro por status: 'aprovado', 'recusado' ou omitir para todos"),
    current_user: schemas.UsuarioProfile = Depends(get_current_medico_user),
    db: firestore.client = Depends(get_db)
):
    """(Médico) Lista o histórico de relatórios já avaliados pelo médico (aprovados + recusados)."""
    return crud.listar_historico_relatorios_medico(db, current_user.id, negocio_id, status)

@app.get("/relatorios/{relatorio_id}", response_model=schemas.RelatorioCompletoResponse, tags=["Relatórios Médicos"])
def get_relatorio_completo_endpoint(
    relatorio: Dict = Depends(get_relatorio_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Autorizado) Retorna a visão completa e consolidada de um relatório."""
    paciente_id = relatorio.get("paciente_id")
    consulta_id = relatorio.get("consulta_id")

    paciente_doc = db.collection('usuarios').document(paciente_id).get()
    if not paciente_doc.exists:
        raise HTTPException(status_code=404, detail="Paciente associado ao relatório não encontrado.")
    
    paciente_data = paciente_doc.to_dict()
    paciente_data['id'] = paciente_doc.id
    
    # Descriptografar dados sensíveis do paciente para médicos
    if 'nome' in paciente_data and paciente_data['nome']:
        try:
            paciente_data['nome'] = decrypt_data(paciente_data['nome'])
        except Exception as e:
            logger.error(f"Erro ao descriptografar nome do paciente {paciente_id}: {e}")
            paciente_data['nome'] = "[Erro na descriptografia]"
    
    if 'telefone' in paciente_data and paciente_data['telefone']:
        try:
            paciente_data['telefone'] = decrypt_data(paciente_data['telefone'])
        except Exception as e:
            logger.error(f"Erro ao descriptografar telefone do paciente {paciente_id}: {e}")
            paciente_data['telefone'] = "[Erro na descriptografia]"

    # Busca registros dos últimos 30 dias
    data_inicio = datetime.utcnow() - timedelta(days=30)
    registros_diarios = crud.listar_registros_diario_estruturado(db, paciente_id, data=data_inicio)

    return {
        "relatorio": relatorio,
        "paciente": paciente_data,
        "planoCuidado": crud.get_ficha_completa_paciente(db, paciente_id, consulta_id),
        "registrosDiarios": registros_diarios
    }

@app.post("/relatorios/{relatorio_id}/aprovar", response_model=schemas.RelatorioMedicoResponse, tags=["Relatórios Médicos - Médico"])
def aprovar_relatorio_endpoint(
    relatorio_id: str,
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase), # Usamos a geral para pegar o ID
    db: firestore.client = Depends(get_db)
):
    """(Médico) Aprova um relatório médico."""
    try:
        relatorio_aprovado = crud.aprovar_relatorio(db, relatorio_id, current_user.id)
        return relatorio_aprovado
    except HTTPException as e:
        raise e
    except Exception as e:
        logger.error(f"Erro ao aprovar relatório: {e}")
        raise HTTPException(status_code=500, detail="Erro interno ao aprovar o relatório.")

@app.post("/relatorios/{relatorio_id}/recusar", response_model=schemas.RelatorioMedicoResponse, tags=["Relatórios Médicos - Médico"])
def recusar_relatorio_endpoint(
    relatorio_id: str,
    recusa_data: schemas.RecusarRelatorioRequest,
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """(Médico) Recusa um relatório médico com uma justificativa."""
    try:
        relatorio_recusado = crud.recusar_relatorio(db, relatorio_id, current_user.id, recusa_data.motivo)
        return relatorio_recusado
    except HTTPException as e:
        raise e
    except Exception as e:
        logger.error(f"Erro ao recusar relatório: {e}")
        raise HTTPException(status_code=500, detail="Erro interno ao recusar o relatório.")

@app.put("/relatorios/{relatorio_id}", response_model=schemas.RelatorioMedicoResponse, tags=["Relatórios Médicos"])
def atualizar_relatorio_endpoint(
    relatorio_id: str,
    update_data: schemas.RelatorioMedicoUpdate,
    current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin ou Profissional) Atualiza o conteúdo de um relatório médico."""
    try:
        relatorio_atualizado = crud.atualizar_relatorio_medico(db, relatorio_id, update_data, current_user.id)
        if not relatorio_atualizado:
            raise HTTPException(status_code=404, detail="Relatório não encontrado.")
        return relatorio_atualizado
    except HTTPException as e:
        raise e
    except Exception as e:
        logger.error(f"Erro ao atualizar relatório: {e}")
        raise HTTPException(status_code=500, detail="Erro interno ao atualizar o relatório.")
    
# =================================================================================
# ENDPOINTS DE SUPORTE PSICOLÓGICO
# =================================================================================

@app.get("/pacientes/{paciente_id}/suporte-psicologico", response_model=List[schemas.SuportePsicologicoResponse], tags=["Suporte Psicológico"])
def get_suportes_psicologicos(
    paciente_id: str,
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Admin, Enfermeiro ou Técnico) Lista todos os recursos de suporte psicológico do paciente."""
    return crud.listar_suportes_psicologicos(db, paciente_id)

@app.post("/pacientes/{paciente_id}/suporte-psicologico", response_model=schemas.SuportePsicologicoResponse, status_code=status.HTTP_201_CREATED, tags=["Suporte Psicológico"])
def create_suporte_psicologico(
    paciente_id: str,
    suporte_data: schemas.SuportePsicologicoCreate,
    negocio_id: str = Depends(validate_negocio_id),
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Admin, Enfermeiro ou Técnico) Cria um novo recurso de suporte (link ou texto)."""
    return crud.criar_suporte_psicologico(db, paciente_id, negocio_id, suporte_data, current_user.id)

@app.put("/pacientes/{paciente_id}/suporte-psicologico/{suporte_id}", response_model=schemas.SuportePsicologicoResponse, tags=["Suporte Psicológico"])
def update_suporte_psicologico(
    paciente_id: str,
    suporte_id: str,
    update_data: schemas.SuportePsicologicoUpdate,
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Admin, Enfermeiro ou Técnico) Atualiza um recurso de suporte existente."""
    suporte_atualizado = crud.atualizar_suporte_psicologico(db, paciente_id, suporte_id, update_data)
    if not suporte_atualizado:
        raise HTTPException(status_code=404, detail="Recurso de suporte não encontrado.")
    return suporte_atualizado

@app.delete("/pacientes/{paciente_id}/suporte-psicologico/{suporte_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Suporte Psicológico"])
def delete_suporte_psicologico(
    paciente_id: str,
    suporte_id: str,
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """(Admin, Enfermeiro ou Técnico) Deleta um recurso de suporte."""
    if not crud.deletar_suporte_psicologico(db, paciente_id, suporte_id):
        raise HTTPException(status_code=404, detail="Recurso de suporte não encontrado.")
    return


@app.patch("/negocios/{negocio_id}/usuarios/{user_id}/consent", response_model=schemas.UsuarioProfile, tags=["Admin - Gestão do Negócio"])
def update_user_consent(
    negocio_id: str = Depends(validate_path_negocio_id),
    user_id: str = Path(..., description="ID do usuário a ser atualizado."),
    consent_data: schemas.ConsentimentoLGPDUpdate = ...,
    # Permissão: Apenas Admin ou Profissional do negócio podem atualizar o consentimento
    current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """(Admin ou Enfermeiro) Atualiza os dados de consentimento LGPD de um usuário."""
    usuario_atualizado = crud.atualizar_consentimento_lgpd(db, user_id, consent_data)
    
    if not usuario_atualizado:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")
        
    return usuario_atualizado


# Em main.py, adicione este novo endpoint

@app.patch("/me/consent", response_model=schemas.UsuarioProfile, tags=["Usuários"])
def update_my_consent(
    consent_data: schemas.ConsentimentoLGPDUpdate,
    # Permissão: Qualquer usuário autenticado pode dar consentimento em seu próprio perfil.
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """
    (Qualquer Usuário Autenticado) Atualiza os dados de consentimento LGPD do próprio usuário.
    """
    # A função CRUD é a mesma, apenas passamos o ID do usuário logado.
    usuario_atualizado = crud.atualizar_consentimento_lgpd(db, current_user.id, consent_data)
    
    # A verificação de "não encontrado" não é estritamente necessária aqui,
    # pois o usuário já foi encontrado pela dependência, mas mantemos por segurança.
    if not usuario_atualizado:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")
        
    return usuario_atualizado

# Em main.py, adicione este endpoint

@app.post("/tasks/process-overdue", response_model=schemas.ProcessarTarefasResponse, tags=["Jobs Agendados"])
def process_overdue_tasks(db: firestore.client = Depends(get_db)):
    """
    (PÚBLICO - CHAMADO PELO CLOUD SCHEDULER) Processa tarefas atrasadas
    e envia as notificações necessárias.
    """
    from datetime import datetime, timezone
    
    stats = {"total_verificadas": 0, "total_notificadas": 0, "erros": 0}
    
    try:
        now = datetime.now(timezone.utc)
        logger.info(f"[SCHEDULER] Iniciando processamento - {now}")
        
        verificacao_ref = db.collection('tarefas_a_verificar')
        query = verificacao_ref.where('status', '==', 'pendente').where('dataHoraLimite', '<=', now)
        
        tarefas_para_verificar = list(query.stream())
        stats["total_verificadas"] = len(tarefas_para_verificar)
        
        logger.info(f"[SCHEDULER] Encontradas {len(tarefas_para_verificar)} tarefas")
        
        for doc_verificacao in tarefas_para_verificar:
            try:
                dados = doc_verificacao.to_dict()
                tarefa_id = dados.get('tarefaId')
                
                if tarefa_id:
                    tarefa_ref = db.collection('tarefas_essenciais').document(tarefa_id)
                    tarefa_doc = tarefa_ref.get()
                    
                    if tarefa_doc.exists and not tarefa_doc.to_dict().get('foiConcluida', False):
                        stats["total_notificadas"] += 1
                
                doc_verificacao.reference.update({"status": "processado"})
                
            except Exception as e:
                stats["erros"] += 1
                logger.error(f"[SCHEDULER] Erro individual: {e}")

        logger.info(f"[SCHEDULER] Concluído: {stats}")
        return stats
        
    except Exception as e:
        logger.error(f"[SCHEDULER] Erro geral: {e}")
        stats["erros"] += 1
        return stats


@app.post("/tasks/process-overdue-debug", tags=["Jobs Agendados"])
def process_overdue_tasks_debug():
    """
    Endpoint de debug para testar sem dependências do Firestore
    """
    try:
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc)
        return {
            "status": "success",
            "timestamp": now.isoformat(),
            "message": "Endpoint funcional"
        }
    except Exception as e:
        import traceback
        return {
            "status": "error", 
            "error": str(e),
            "traceback": traceback.format_exc()
        }


def processar_notificacoes_agendadas(db: firestore.client, now: datetime) -> dict:
    """
    Processa notificações agendadas que estão prontas para serem enviadas.
    """
    stats = {
        "notificacoes_verificadas": 0,
        "notificacoes_enviadas": 0,
        "notificacoes_erro": 0
    }

    try:
        # Buscar notificações agendadas que devem ser enviadas agora
        notificacoes_ref = db.collection('notificacoes_agendadas')
        query = notificacoes_ref.where('status', '==', 'agendada').where('data_agendamento', '<=', now)

        notificacoes_pendentes = list(query.stream())
        stats["notificacoes_verificadas"] = len(notificacoes_pendentes)

        logger.info(f"Encontradas {len(notificacoes_pendentes)} notificações para processar")

        for doc_notificacao in notificacoes_pendentes:
            try:
                notif_data = doc_notificacao.to_dict()
                paciente_id = notif_data.get('paciente_id')
                titulo = notif_data.get('titulo')
                mensagem = notif_data.get('mensagem')

                if not paciente_id:
                    logger.warning(f"Notificação {doc_notificacao.id} sem paciente_id")
                    continue

                # Buscar dados do paciente
                paciente_doc = db.collection('usuarios').document(paciente_id).get()
                if not paciente_doc.exists:
                    logger.warning(f"Paciente {paciente_id} não encontrado")
                    doc_notificacao.reference.update({"status": "erro", "erro": "Paciente não encontrado"})
                    stats["notificacoes_erro"] += 1
                    continue

                paciente_data = paciente_doc.to_dict()
                tokens_fcm = paciente_data.get('fcm_tokens', [])

                # Persistir notificação no banco do paciente
                db.collection('usuarios').document(paciente_id).collection('notificacoes').add({
                    "title": titulo,
                    "body": mensagem,
                    "tipo": "LEMBRETE_AGENDADO",
                    "relacionado": {"notificacao_agendada_id": doc_notificacao.id},
                    "lida": False,
                    "data_criacao": firestore.SERVER_TIMESTAMP,
                    "dedupe_key": f"AGENDADA_{doc_notificacao.id}"
                })

                # HÍBRIDO: Tenta Web Push VAPID primeiro, depois FCM como fallback
                data_payload = {"tipo": "LEMBRETE_AGENDADO", "notificacao_agendada_id": doc_notificacao.id}
                webpush_tag = f"LEMBRETE_AGENDADO-{doc_notificacao.id}-paciente-{paciente_id}"
                enviado_vapid = False

                # 1. Tentar Web Push VAPID
                webpush_subscription = paciente_data.get('webpush_subscription_exames')
                if webpush_subscription:
                    try:
                        from pywebpush import webpush, WebPushException
                        from vapid_config import VAPID_PRIVATE_KEY, VAPID_CLAIMS_EMAIL
                        import json

                        payload = json.dumps({
                            "title": titulo,
                            "body": mensagem,
                            "data": data_payload,
                            "tag": webpush_tag
                        })

                        webpush(
                            subscription_info={
                                "endpoint": webpush_subscription["endpoint"],
                                "keys": webpush_subscription["keys"]
                            },
                            data=payload,
                            vapid_private_key=VAPID_PRIVATE_KEY,
                            vapid_claims={"sub": VAPID_CLAIMS_EMAIL}
                        )

                        enviado_vapid = True
                        logger.info(f"✅ LEMBRETE_AGENDADO enviado via Web Push para {paciente_id}")

                    except WebPushException as e:
                        logger.error(f"❌ Erro Web Push para {paciente_id}: {e}")
                        if e.response and e.response.status_code == 410:
                            paciente_doc.reference.update({"webpush_subscription_exames": firestore.DELETE_FIELD})
                    except Exception as e:
                        logger.error(f"❌ Erro Web Push para {paciente_id}: {e}")

                # 2. Fallback: FCM (se VAPID não enviou)
                if not enviado_vapid and tokens_fcm:
                    try:
                        from firebase_admin import messaging

                        message = messaging.MulticastMessage(
                            notification=messaging.Notification(
                                title=titulo,
                                body=mensagem
                            ),
                            data=data_payload,
                            tokens=tokens_fcm
                        )

                        response = messaging.send_multicast(message)
                        logger.info(f"✅ LEMBRETE_AGENDADO enviado via FCM: {response.success_count} sucessos")

                        # Remover tokens inválidos
                        if response.failure_count > 0:
                            valid_tokens = []
                            for idx, resp in enumerate(response.responses):
                                if resp.success:
                                    valid_tokens.append(tokens_fcm[idx])
                                else:
                                    logger.warning(f"Token FCM inválido removido: {resp.exception}")

                            if len(valid_tokens) != len(tokens_fcm):
                                db.collection('usuarios').document(paciente_id).update({
                                    "fcm_tokens": valid_tokens
                                })

                    except Exception as e:
                        logger.error(f"Erro ao enviar push notification: {e}")

                # Marcar notificação como enviada
                doc_notificacao.reference.update({
                    "status": "enviada",
                    "data_envio": firestore.SERVER_TIMESTAMP
                })

                stats["notificacoes_enviadas"] += 1
                logger.info(f"Notificação {doc_notificacao.id} enviada com sucesso")

            except Exception as e:
                logger.error(f"Erro ao processar notificação {doc_notificacao.id}: {e}")
                stats["notificacoes_erro"] += 1
                try:
                    doc_notificacao.reference.update({
                        "status": "erro",
                        "erro": str(e),
                        "data_erro": firestore.SERVER_TIMESTAMP
                    })
                except:
                    pass

        return stats

    except Exception as e:
        logger.error(f"Erro geral no processamento de notificações: {e}")
        stats["notificacoes_erro"] += 1
        return stats


@app.post("/tasks/process-overdue-v2", response_model=schemas.ProcessarTarefasResponse, tags=["Jobs Agendados"])
def process_overdue_tasks_v2(db: firestore.client = Depends(get_db)):
    """
    (PÚBLICO) Processa tarefas atrasadas, notificações agendadas e lembretes de exames.
    [CORRIGIDO PARA USAR A LÓGICA DE NOTIFICAÇÃO CENTRALIZADA]
    """
    from datetime import datetime, timezone
    
    stats = {"total_verificadas": 0, "total_notificadas": 0, "erros": 0}
    now = datetime.now(timezone.utc)
    
    try:
        logger.info(f"--- INICIANDO JOB AGENDADO (process-overdue-v2) - {now.isoformat()} ---")
        
        # 1. Processar Tarefas Atrasadas
        verificacao_ref = db.collection('tarefas_a_verificar')
        query = verificacao_ref.where('status', '==', 'pendente').where('dataHoraLimite', '<=', now)
        
        tarefas_para_verificar = list(query.stream())

        stats["total_verificadas"] = len(tarefas_para_verificar)
        logger.info(f"Tarefas pendentes encontradas para verificação: {stats['total_verificadas']}")

        if tarefas_para_verificar:
            for doc_verificacao in tarefas_para_verificar:
                try:
                    dados_verificacao = doc_verificacao.to_dict()
                    tarefa_id = dados_verificacao.get('tarefaId')
                    if not tarefa_id: continue

                    tarefa_ref = db.collection('tarefas_essenciais').document(tarefa_id)
                    tarefa_doc = tarefa_ref.get()

                    # Verifica se a tarefa ainda existe e não foi concluída
                    if tarefa_doc.exists and not tarefa_doc.to_dict().get('foiConcluida', False):
                        
                        # --- INÍCIO DA CORREÇÃO ---
                        # LÓGICA ANTIGA E INCORRETA REMOVIDA.
                        # AGORA CHAMA A FUNÇÃO CENTRALIZADA E CORRETA DO CRUD.
                        crud._notificar_tarefa_atrasada(db, dados_verificacao)
                        stats["total_notificadas"] += 1
                        # --- FIM DA CORREÇÃO ---

                    doc_verificacao.reference.update({"status": "processado"})

                except Exception as e:
                    stats["erros"] += 1
                    logger.error(f"Erro ao processar tarefa atrasada {doc_verificacao.id}: {e}")
                    doc_verificacao.reference.update({"status": "erro", "erro": str(e)})

        # 2. Processar outras tarefas agendadas (lógica existente permanece)
        try:
            logger.info("Iniciando processamento de notificações agendadas")
            stats.update(crud.processar_notificacoes_agendadas(db, now))
        except Exception as e:
            logger.error(f"Erro no processamento de notificações agendadas: {e}")

        try:
            logger.info("Iniciando processamento de lembretes de exames")
            stats.update(crud.processar_lembretes_exames(db))
        except Exception as e:
            logger.error(f"Erro no processamento de lembretes de exames: {e}")

    except Exception as e:
        stats["erros"] += 1
        logger.error(f"Erro geral no job agendado: {e}")

    logger.info(f"Processamento de jobs concluído: {stats}")
    return stats

@app.post("/processar-lembretes-exames", tags=["Jobs Agendados"])
def processar_lembretes_exames_endpoint(db: firestore.client = Depends(get_db)):
    """
    Endpoint para processar lembretes dinâmicos de exames.
    - COM horário: envia 1h antes
    - SEM horário: envia às 09:00 do dia
    """
    try:
        logger.info("--- INICIANDO PROCESSAMENTO DE LEMBRETES DE EXAMES ---")
        stats = crud.processar_lembretes_exames(db)
        logger.info(f"Lembretes processados: {stats}")
        return stats
    except Exception as e:
        logger.error(f"Erro ao processar lembretes de exames: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/test-notificacao/{paciente_id}", tags=["Debug"])
def test_notificacao_paciente(paciente_id: str, db: firestore.client = Depends(get_db)):
    """Envia notificação de teste para um paciente específico"""
    from firebase_admin import messaging
    try:
        paciente_doc = db.collection('usuarios').document(paciente_id).get()
        if not paciente_doc.exists:
            raise HTTPException(status_code=404, detail="Paciente não encontrado")

        paciente_data = paciente_doc.to_dict()
        fcm_tokens = paciente_data.get('fcm_tokens', [])

        if not fcm_tokens:
            return {"erro": "Paciente não tem FCM tokens registrados"}

        titulo = "Teste de Notificação"
        corpo = "Esta é uma notificação de teste do sistema."

        resultados = []
        for token in fcm_tokens:
            try:
                message = messaging.Message(
                    notification=messaging.Notification(title=titulo, body=corpo),
                    data={"tipo": "TESTE", "paciente_id": paciente_id},
                    token=token
                )
                response = messaging.send(message)
                resultados.append({"token": token[:20] + "...", "status": "enviado", "response": response})
            except Exception as e:
                resultados.append({"token": token[:20] + "...", "status": "erro", "erro": str(e)})

        return {
            "paciente_id": paciente_id,
            "total_tokens": len(fcm_tokens),
            "resultados": resultados
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================================
# WEB PUSH VAPID ENDPOINTS (Apenas para Lembretes de Exames)
# ============================================================================

@app.get("/vapid-public-key", tags=["Web Push"])
def get_vapid_public_key():
    """Retorna a chave pública VAPID para o frontend configurar Web Push"""
    from vapid_config import VAPID_PUBLIC_KEY
    return {"publicKey": VAPID_PUBLIC_KEY}

class WebPushSubscription(BaseModel):
    endpoint: str
    keys: dict  # {"p256dh": "...", "auth": "..."}

@app.post("/usuarios/{usuario_id}/webpush-subscription", tags=["Web Push"])
def salvar_webpush_subscription(
    usuario_id: str,
    subscription: WebPushSubscription,
    db: firestore.client = Depends(get_db)
):
    """
    Salva o Web Push subscription do usuário (apenas para lembretes de exames).
    Frontend deve chamar após usuário permitir notificações.
    """
    try:
        usuario_ref = db.collection('usuarios').document(usuario_id)
        usuario_doc = usuario_ref.get()

        if not usuario_doc.exists:
            raise HTTPException(status_code=404, detail="Usuário não encontrado")

        # Salvar subscription
        subscription_data = {
            "endpoint": subscription.endpoint,
            "keys": subscription.keys,
            "created_at": firestore.SERVER_TIMESTAMP
        }

        usuario_ref.update({
            "webpush_subscription_exames": subscription_data
        })

        return {"status": "success", "message": "Web Push subscription salva com sucesso"}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/usuarios/{usuario_id}/webpush-subscription", tags=["Web Push"])
def remover_webpush_subscription(
    usuario_id: str,
    db: firestore.client = Depends(get_db)
):
    """Remove o Web Push subscription do usuário"""
    try:
        usuario_ref = db.collection('usuarios').document(usuario_id)
        usuario_ref.update({
            "webpush_subscription_exames": firestore.DELETE_FIELD
        })
        return {"status": "success", "message": "Subscription removida"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/tasks/debug-verificacao", tags=["Jobs Agendados"])
def debug_verificacao(db: firestore.client = Depends(get_db)):
    """Debug: Mostra o que há na coleção tarefas_a_verificar"""
    from datetime import datetime, timezone
    
    try:
        now = datetime.now(timezone.utc)
        
        # Buscar TODOS os documentos (sem filtro)
        verificacao_ref = db.collection('tarefas_a_verificar')
        todos_docs = list(verificacao_ref.stream())
        
        # Buscar apenas pendentes
        pendentes = list(verificacao_ref.where('status', '==', 'pendente').stream())
        
        # Buscar pendentes vencidos
        vencidos = list(verificacao_ref.where('status', '==', 'pendente').where('dataHoraLimite', '<=', now).stream())
        
        resultado = {
            "timestamp_atual": now.isoformat(),
            "total_documentos": len(todos_docs),
            "total_pendentes": len(pendentes), 
            "total_vencidos": len(vencidos),
            "documentos": []
        }
        
        for doc in todos_docs[:10]:  # Primeiros 10 para debug
            data = doc.to_dict()
            resultado["documentos"].append({
                "id": doc.id,
                "tarefaId": data.get('tarefaId'),
                "status": data.get('status'),
                "dataHoraLimite": data.get('dataHoraLimite').isoformat() if data.get('dataHoraLimite') else None,
                "vencido": data.get('dataHoraLimite') <= now if data.get('dataHoraLimite') else False
            })
            
        return resultado
        
    except Exception as e:
        return {"erro": str(e)}

@app.post("/tasks/debug-technician-notifications", tags=["Jobs Agendados"])
def debug_technician_notifications(db: firestore.client = Depends(get_db)):
    """(PÚBLICO - DEBUG) Testa notificações para técnicos especificamente"""
    from datetime import datetime, timezone

    debug_info = {
        "timestamp": datetime.now().isoformat(),
        "tarefas_verificacao_encontradas": 0,
        "tarefas_atrasadas": 0,
        "pacientes_com_tecnicos": 0,
        "tecnicos_notificados": 0,
        "detalhes": []
    }

    try:
        now = datetime.now(timezone.utc)

        # 1. Buscar tarefas de verificação pendentes
        verificacao_ref = db.collection("tarefas_a_verificar")
        pendentes = list(verificacao_ref.where("status", "==", "pendente").stream())
        debug_info["tarefas_verificacao_encontradas"] = len(pendentes)

        for doc in pendentes:
            dados = doc.to_dict()
            tarefa_id = dados.get("tarefaId")
            paciente_id = dados.get("pacienteId")
            data_limite = dados.get("dataHoraLimite")

            # Verificar se está vencida
            vencida = False
            if data_limite:
                if hasattr(data_limite, "replace"):
                    if data_limite.tzinfo is None:
                        data_limite = data_limite.replace(tzinfo=timezone.utc)
                    else:
                        data_limite = data_limite.astimezone(timezone.utc)
                vencida = data_limite <= now

            if vencida:
                # 2. Verificar se tarefa está realmente não concluída
                tarefa_doc = db.collection("tarefas_essenciais").document(tarefa_id).get()
                if tarefa_doc.exists and not tarefa_doc.to_dict().get("foiConcluida", False):
                    debug_info["tarefas_atrasadas"] += 1

                    # 3. Buscar técnicos do paciente
                    paciente_doc = db.collection("usuarios").document(paciente_id).get()
                    if paciente_doc.exists:
                        paciente_data = paciente_doc.to_dict()
                        tecnicos_ids = paciente_data.get("tecnicos_ids", [])

                        if tecnicos_ids:
                            debug_info["pacientes_com_tecnicos"] += 1
                            debug_info["detalhes"].append({
                                "tarefa_id": tarefa_id,
                                "paciente_id": paciente_id,
                                "tecnicos_ids": tecnicos_ids,
                                "quantidade_tecnicos": len(tecnicos_ids),
                                "tarefa_descricao": tarefa_doc.to_dict().get("descricao", "N/A"),
                                "data_limite": data_limite.isoformat() if data_limite else None,
                                "vencida": vencida
                            })
                            debug_info["tecnicos_notificados"] += len(tecnicos_ids)

        return debug_info

    except Exception as e:
        return {"erro": str(e), "debug_info": debug_info}

# ADICIONE ESTE ENDPOINT NO SEU ARQUIVO main.py

@app.post("/me/logout", status_code=status.HTTP_200_OK, tags=["Usuários"])
def logout_user(
    request: schemas.FCMTokenRequest,
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase),
    db: firestore.client = Depends(get_db)
):
    """
    (Autenticado) Remove o token de notificação (FCM) do usuário ao fazer logout.
    O frontend DEVE chamar este endpoint ANTES de deslogar o usuário localmente.
    """
    if not request.fcm_token:
        # Retorna sucesso mesmo que o token não seja enviado para não quebrar o fluxo de logout no front.
        logger.warning(f"Logout para usuário {current_user.id} sem Fcm Token fornecido.")
        return {"message": "Logout processado sem remoção de token."}
    try:
        logger.info(f"Removendo token FCM para o usuário {current_user.id} durante o logout.")
        crud.remover_fcm_token(db, current_user.firebase_uid, request.fcm_token)
        return {"message": "Token FCM removido com sucesso."}
    except Exception as e:
        logger.error(f"Erro ao remover token FCM no logout para o UID {current_user.firebase_uid}: {e}")
        # Retorna sucesso mesmo se falhar para não bloquear o logout no frontend.
        return {"message": "Processo de logout no backend concluído (com erro interno na remoção do token)."}
    

# Em main.py, adicione estes dois novos endpoints

@app.get("/negocios/{negocio_id}/usuarios/{user_id}", response_model=schemas.UsuarioProfile, tags=["Admin - Gestão do Negócio"])
def get_detalhes_usuario_negocio(
    user_id: str,
    negocio_id: str = Depends(validate_path_negocio_id),
    current_user: schemas.UsuarioProfile = Depends(get_current_admin_or_profissional_user),
    db: firestore.client = Depends(get_db)
):
    """
    (Admin ou Profissional) Retorna os detalhes de um usuário específico do negócio.
    """
    usuario = crud.get_usuario_por_id(db, user_id)
    if not usuario or negocio_id not in usuario.get('roles', {}):
        raise HTTPException(status_code=404, detail="Usuário não encontrado ou não pertence a este negócio.")
    
    # Garante que todos os campos do schema sejam preenchidos
    usuario.setdefault('fcm_tokens', [])
    usuario.setdefault('apns_tokens', [])
    
    return usuario

@app.get("/pacientes/{paciente_id}/dados-completos", response_model=schemas.UsuarioProfile, tags=["Ficha do Paciente"])
def get_dados_completos_paciente(
    paciente_id: str,
    current_user: schemas.UsuarioProfile = Depends(get_paciente_autorizado),
    db: firestore.client = Depends(get_db)
):
    """
    (Autorizado) Retorna os dados completos de um paciente, incluindo a URL da imagem de perfil.
    """
    paciente = crud.get_usuario_por_id(db, paciente_id)
    if not paciente:
        raise HTTPException(status_code=404, detail="Paciente não encontrado.")
    
    # Garante que todos os campos do schema sejam preenchidos para evitar erros
    paciente.setdefault('fcm_tokens', [])
    paciente.setdefault('apns_tokens', [])
    
    return paciente
# =================================================================================
# ENDPOINTS CLOUD TASKS - NOTIFICAÇÕES AGENDADAS
# =================================================================================

@app.post(
    "/internal/notificar-tarefa-atrasada",
    response_model=NotificarTarefaAtrasadaResponse,
    tags=["Internal - Cloud Tasks"]
)
async def processar_notificacao_tarefa_atrasada(
    request: Request,
    payload: NotificarTarefaAtrasadaRequest,
    db: firestore.client = Depends(get_db)
):
    """
    Endpoint INTERNO chamado pelo Cloud Tasks para enviar notificação de tarefa atrasada.
    
    SEGURANÇA: Chamado apenas pelo Cloud Tasks via OIDC token.
    """
    try:
        logger.info(f"📨 Recebido webhook do Cloud Tasks para tarefa {payload.tarefa_id}")

        # Valida se tarefa existe e não foi concluída
        tarefa_ref = db.collection('tarefas_essenciais').document(payload.tarefa_id)
        tarefa_doc = tarefa_ref.get()

        if not tarefa_doc.exists:
            logger.warning(f"⚠️ Tarefa {payload.tarefa_id} não existe mais")
            return NotificarTarefaAtrasadaResponse(
                success=True,
                message="Tarefa não existe mais",
                tarefa_id=payload.tarefa_id
            )

        tarefa_data = tarefa_doc.to_dict()

        if tarefa_data.get('foiConcluida'):
            logger.info(f"ℹ️ Tarefa {payload.tarefa_id} já foi concluída")
            return NotificarTarefaAtrasadaResponse(
                success=True,
                message="Tarefa já foi concluída",
                tarefa_id=payload.tarefa_id
            )

        # Envia notificações
        crud.enviar_notificacoes_tarefa_atrasada(
            db=db,
            tarefa_id=payload.tarefa_id,
            paciente_id=payload.paciente_id,
            negocio_id=payload.negocio_id,
            criado_por_id=payload.criado_por_id,
            descricao=payload.descricao
        )

        logger.info(f"✅ Notificações enviadas para tarefa {payload.tarefa_id}")

        return NotificarTarefaAtrasadaResponse(
            success=True,
            message="Notificações enviadas com sucesso",
            tarefa_id=payload.tarefa_id
        )

    except Exception as e:
        logger.error(f"❌ Erro ao processar notificação: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Erro ao processar notificação: {str(e)}"
        )


@app.post(
    "/internal/notificar-lembrete-exame",
    response_model=NotificarLembreteExameResponse,
    tags=["Internal - Cloud Tasks"]
)
async def processar_lembrete_exame(
    payload: NotificarLembreteExameRequest,
    db: firestore.client = Depends(get_db)
):
    """
    Endpoint INTERNO chamado pelo Cloud Tasks para enviar lembrete de exame.

    SEGURANÇA: Chamado apenas pelo Cloud Tasks via OIDC token.
    """
    try:
        print("=" * 80)
        print("🔔 [LEMBRETE EXAME] Endpoint /internal/notificar-lembrete-exame chamado!")
        print(f"📦 [LEMBRETE EXAME] Payload recebido: {payload.dict()}")
        print(f"🔍 [LEMBRETE EXAME] IDs extraídos:")
        print(f"   - exame_id: {payload.exame_id}")
        print(f"   - paciente_id: {payload.paciente_id}")
        print(f"   - negocio_id: {payload.negocio_id}")
        print(f"   - nome_exame: {payload.nome_exame}")
        print(f"   - data_exame: {payload.data_exame}")
        print(f"   - horario_exame: {payload.horario_exame}")

        logger.info(f"📨 Recebido webhook do Cloud Tasks para exame {payload.exame_id}")

        # Valida se exame existe
        print(f"🔍 [LEMBRETE EXAME] Buscando exame {payload.exame_id} do paciente {payload.paciente_id}...")
        exame_ref = db.collection('usuarios').document(payload.paciente_id).collection('exames').document(payload.exame_id)
        exame_doc = exame_ref.get()

        if not exame_doc.exists:
            print(f"❌ [LEMBRETE EXAME] Exame {payload.exame_id} não encontrado!")
            logger.warning(f"⚠️ Exame {payload.exame_id} não existe mais")
            return NotificarLembreteExameResponse(
                success=True,
                message="Exame não existe mais",
                exame_id=payload.exame_id
            )

        exame_data = exame_doc.to_dict()
        print(f"✅ [LEMBRETE EXAME] Exame encontrado: {exame_data.get('nome_exame')}")

        # Buscar paciente
        print(f"🔍 [LEMBRETE EXAME] Buscando dados do paciente {payload.paciente_id}...")
        paciente_ref = db.collection('usuarios').document(payload.paciente_id)
        paciente_doc = paciente_ref.get()

        if not paciente_doc.exists:
            print(f"❌ [LEMBRETE EXAME] Paciente {payload.paciente_id} não encontrado!")
            logger.warning(f"⚠️ Paciente {payload.paciente_id} não encontrado")
            return NotificarLembreteExameResponse(
                success=False,
                message="Paciente não encontrado",
                exame_id=payload.exame_id
            )

        paciente_data = paciente_doc.to_dict()
        fcm_tokens = paciente_data.get('fcm_tokens', [])
        apns_tokens = paciente_data.get('apns_tokens', [])
        print(f"✅ [LEMBRETE EXAME] Paciente encontrado. FCM tokens: {len(fcm_tokens)}, APNs tokens: {len(apns_tokens)}")

        if not fcm_tokens and not apns_tokens:
            print(f"⚠️ [LEMBRETE EXAME] Paciente não tem tokens de notificação!")
            logger.warning(f"⚠️ Paciente {payload.paciente_id} sem tokens")

        # Envia lembrete
        print(f"📤 [LEMBRETE EXAME] Chamando crud.enviar_lembrete_exame()...")
        crud.enviar_lembrete_exame(
            db=db,
            exame_id=payload.exame_id,
            paciente_id=payload.paciente_id,
            negocio_id=payload.negocio_id,
            nome_exame=payload.nome_exame,
            data_exame=payload.data_exame,
            horario_exame=payload.horario_exame
        )

        print(f"✅ [LEMBRETE EXAME] crud.enviar_lembrete_exame() concluído!")
        print("=" * 80)
        logger.info(f"✅ Lembrete enviado para exame {payload.exame_id}")

        return NotificarLembreteExameResponse(
            success=True,
            message="Lembrete enviado com sucesso",
            exame_id=payload.exame_id
        )

    except Exception as e:
        print(f"❌ [LEMBRETE EXAME] ERRO CRÍTICO: {str(e)}")
        print(f"❌ [LEMBRETE EXAME] Traceback completo:")
        import traceback
        print(traceback.format_exc())
        print("=" * 80)
        logger.error(f"❌ Erro ao processar lembrete: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Erro ao processar lembrete: {str(e)}"
        )


@app.post(
    "/tasks/test-notificacao-atrasada/{tarefa_id}",
    tags=["Jobs Agendados", "Debug"]
)
def testar_notificacao_tarefa_atrasada(
    tarefa_id: str,
    db: firestore.client = Depends(get_db),
    current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase)
):
    """
    Endpoint de TESTE para disparar notificação manualmente.
    """
    try:
        tarefa_ref = db.collection('tarefas_essenciais').document(tarefa_id)
        tarefa_doc = tarefa_ref.get()

        if not tarefa_doc.exists:
            raise HTTPException(status_code=404, detail=f"Tarefa {tarefa_id} não encontrada")

        tarefa_data = tarefa_doc.to_dict()

        crud.enviar_notificacoes_tarefa_atrasada(
            db=db,
            tarefa_id=tarefa_id,
            paciente_id=tarefa_data['pacienteId'],
            negocio_id=tarefa_data['negocioId'],
            criado_por_id=tarefa_data['criadoPorId'],
            descricao=tarefa_data.get('descricao', 'Tarefa de teste')
        )

        return {
            "success": True,
            "message": f"Notificação de teste enviada para tarefa {tarefa_id}",
            "tarefa_id": tarefa_id
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao testar notificação: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
