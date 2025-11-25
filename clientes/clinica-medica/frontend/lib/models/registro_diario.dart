// lib/models/registro_diario.dart - AJUSTE FINAL

import 'package:analicegrubert/models/usuario.dart';

enum TipoRegistro {
  sinaisVitais,
  medicacao,
  intercorrencia,
  atividade,
  anotacao,
  anamnese
}

class RegistroDiario {
  final String id;
  final String pacienteId;
  final TipoRegistro tipo;
  final DateTime dataHora;
  final Usuario tecnico;
  final String? anotacoes;

  // Campos mantidos para compatibilidade de leitura, mas não devem ser usados para exibição
  final SinaisVitais? sinaisVitais;
  final AdministracaoMedicacao? medicacao;
  final Intercorrencia? intercorrencia;
  final AtividadeRealizada? atividade;

  const RegistroDiario({
    required this.id,
    required this.pacienteId,
    required this.tipo,
    required this.dataHora,
    required this.tecnico,
    this.anotacoes,
    this.sinaisVitais,
    this.medicacao,
    this.intercorrencia,
    this.atividade,
  });

  factory RegistroDiario.fromJson(Map<String, dynamic> json) {
    final tipoString = json['tipo'] as String?;
    TipoRegistro tipo;

    switch (tipoString) {
      case 'sinais_vitais': tipo = TipoRegistro.sinaisVitais; break;
      case 'medicacao': tipo = TipoRegistro.medicacao; break;
      case 'intercorrencia': tipo = TipoRegistro.intercorrencia; break;
      case 'atividade': tipo = TipoRegistro.atividade; break;
      case 'anamnese': tipo = TipoRegistro.anamnese; break;
      case 'anotacao':
      default: tipo = TipoRegistro.anotacao; break;
    }

    final conteudo = json['conteudo'] as Map<String, dynamic>?;
    String? anotacoes;

    // *** LÓGICA DE LEITURA CORRIGIDA ***
    // Prioriza o campo 'descricao' que agora é o padrão para texto livre.
    if (conteudo != null && conteudo['descricao'] is String) {
        anotacoes = conteudo['descricao'] as String;
    }

    return RegistroDiario(
      id: json['id'] as String,
      pacienteId: json['paciente_id'] as String,
      tipo: tipo,
      dataHora: DateTime.parse(json['data_registro'] as String),
      tecnico: Usuario.fromJson(json['tecnico'] as Map<String, dynamic>),
      anotacoes: anotacoes,
      // Os campos abaixo serão nulos para novas anotações, o que é o esperado.
      sinaisVitais: tipo == TipoRegistro.sinaisVitais && conteudo != null ? SinaisVitais.fromJson(conteudo) : null,
      medicacao: tipo == TipoRegistro.medicacao && conteudo != null ? AdministracaoMedicacao.fromJson(conteudo) : null,
      intercorrencia: tipo == TipoRegistro.intercorrencia && conteudo != null ? Intercorrencia.fromJson(conteudo) : null,
      atividade: tipo == TipoRegistro.atividade && conteudo != null ? AtividadeRealizada.fromJson(conteudo) : null,
    );
  }
}

// O resto das classes (SinaisVitais, etc.) permanecem as mesmas para não quebrar a leitura de dados muito antigos.
// A lógica de exibição no frontend vai ignorá-las.
class SinaisVitais {
  final double? pressaoSistolica;
  final double? pressaoDiastolica;
  final double? temperatura;
  final int? frequenciaCardiaca;
  final int? frequenciaRespiratoria;
  final double? saturacaoOxigenio;
  final double? peso;
  final double? altura;
  final double? glicemia;

  const SinaisVitais({
    this.pressaoSistolica,
    this.pressaoDiastolica,
    this.temperatura,
    this.frequenciaCardiaca,
    this.frequenciaRespiratoria,
    this.saturacaoOxigenio,
    this.peso,
    this.altura,
    this.glicemia,
  });

  factory SinaisVitais.fromJson(Map<String, dynamic> json) {
    return SinaisVitais(
      pressaoSistolica: (json['pressao_sistolica'] as num?)?.toDouble(),
      pressaoDiastolica: (json['pressao_diastolica'] as num?)?.toDouble(),
      temperatura: (json['temperatura'] as num?)?.toDouble(),
      frequenciaCardiaca: json['frequencia_cardiaca'] as int?,
      frequenciaRespiratoria: json['frequencia_respiratoria'] as int?,
      saturacaoOxigenio: (json['saturacao_oxigenio'] as num?)?.toDouble(),
      peso: (json['peso'] as num?)?.toDouble(),
      altura: (json['altura'] as num?)?.toDouble(),
      glicemia: (json['glicemia'] as num?)?.toDouble(),
    );
  }
}

enum StatusMedicacao { administrado, recusado, naoDisponivel }

class AdministracaoMedicacao {
  final String nomeMedicacao;
  final String dosagem;
  final String viaAdministracao;
  final StatusMedicacao status;
  final String? motivoRecusa;

  const AdministracaoMedicacao({
    required this.nomeMedicacao,
    required this.dosagem,
    required this.viaAdministracao,
    required this.status,
    this.motivoRecusa,
  });

  factory AdministracaoMedicacao.fromJson(Map<String, dynamic> json) {
    final statusString = json['status'] as String? ?? 'administrado';
    StatusMedicacao status;
    switch (statusString) {
      case 'administrado': status = StatusMedicacao.administrado; break;
      case 'recusado': status = StatusMedicacao.recusado; break;
      case 'naoDisponivel': case 'nao_disponivel': status = StatusMedicacao.naoDisponivel; break;
      default: status = StatusMedicacao.administrado; break;
    }
    return AdministracaoMedicacao(
      nomeMedicacao: json['nome_medicacao'] as String? ?? '',
      dosagem: json['dosagem'] as String? ?? '',
      viaAdministracao: json['via_administracao'] as String? ?? '',
      status: status,
      motivoRecusa: json['motivo_recusa'] as String?,
    );
  }
}

enum TipoIntercorrencia { leve, moderada, grave }

class Intercorrencia {
  final TipoIntercorrencia tipo;
  final String descricao;
  final String? acaoTomada;
  final bool comunicadoEnfermeiro;

  const Intercorrencia({
    required this.tipo,
    required this.descricao,
    this.acaoTomada,
    required this.comunicadoEnfermeiro,
  });

  factory Intercorrencia.fromJson(Map<String, dynamic> json) {
    final tipoString = json['tipo'] as String? ?? 'leve';
    TipoIntercorrencia tipo;
    switch (tipoString) {
      case 'leve': tipo = TipoIntercorrencia.leve; break;
      case 'moderada': tipo = TipoIntercorrencia.moderada; break;
      case 'grave': tipo = TipoIntercorrencia.grave; break;
      default: tipo = TipoIntercorrencia.leve; break;
    }
    return Intercorrencia(
      tipo: tipo,
      descricao: json['descricao'] as String? ?? '',
      acaoTomada: json['acao_tomada'] as String?,
      comunicadoEnfermeiro: json['comunicado_enfermeiro'] as bool? ?? false,
    );
  }
}

class AtividadeRealizada {
  final String nomeAtividade;
  final int duracaoMinutos;
  final String? descricao;
  final String? observacoes;

  const AtividadeRealizada({
    required this.nomeAtividade,
    required this.duracaoMinutos,
    this.descricao,
    this.observacoes,
  });

  factory AtividadeRealizada.fromJson(Map<String, dynamic> json) {
    return AtividadeRealizada(
      nomeAtividade: json['nome_atividade'] as String? ?? json['descricao'] as String? ?? 'Atividade',
      duracaoMinutos: json['duracao_minutos'] as int? ?? 0,
      descricao: json['descricao'] as String?,
      observacoes: json['observacoes'] as String?,
    );
  }
}