// lib/models/anamnese.dart

import 'package:flutter/foundation.dart';

@immutable
class Anamnese {
  final String? id;
  final String pacienteId;
  final String responsavelId;
  final String nomePaciente;
  final DateTime dataAvaliacao;

  // 1. Identificação do Paciente
  final int? idade;
  final String? sexo;
  final DateTime? dataNascimento;
  final String? estadoCivil;
  final String? profissao;

  // 3. Histórico de Enfermagem / Anamnese
  final String? queixaPrincipal;
  final String? historicoDoencaAtual;
  final AntecedentesPessoais? antecedentesPessoais;
  final String? historiaFamiliar;

  // 4. Avaliação do Estado Atual
  final SinaisVitais? sinaisVitais;
  final String? nivelConsciencia;
  final String? estadoNutricional;
  final String? peleMucosas;
  final String? sistemaRespiratorio;
  final String? sistemaCardiovascular;
  final String? abdome;
  final String? eliminacoesFisiologicas;
  final String? presencaDrenosSondasCateteres;

  // 5. Aspectos Psicossociais e Espirituais
  final String? apoioFamiliarSocial;
  final String? necessidadesEmocionaisEspirituais;

  const Anamnese({
    this.id,
    required this.pacienteId,
    required this.responsavelId,
    required this.nomePaciente,
    required this.dataAvaliacao,
    this.idade,
    this.sexo,
    this.dataNascimento,
    this.estadoCivil,
    this.profissao,
    this.queixaPrincipal,
    this.historicoDoencaAtual,
    this.antecedentesPessoais,
    this.historiaFamiliar,
    this.sinaisVitais,
    this.nivelConsciencia,
    this.estadoNutricional,
    this.peleMucosas,
    this.sistemaRespiratorio,
    this.sistemaCardiovascular,
    this.abdome,
    this.eliminacoesFisiologicas,
    this.presencaDrenosSondasCateteres,
    this.apoioFamiliarSocial,
    this.necessidadesEmocionaisEspirituais,
  });

  factory Anamnese.fromJson(Map<String, dynamic> json) {
    // Helper para converter qualquer valor para int de forma segura
    int? safeIntParse(dynamic value) {
      if (value == null) return null;
      return int.tryParse(value.toString());
    }

    return Anamnese(
      id: json['id'] as String?,
      pacienteId: json['paciente_id'] as String? ?? '',
      responsavelId: json['responsavel_id'] as String? ?? '',
      nomePaciente: json['nome_paciente'] as String? ?? 'Paciente Desconhecido',
      dataAvaliacao: json['data_avaliacao'] != null
          ? DateTime.parse(json['data_avaliacao'] as String)
          : DateTime.now(),
      // CORREÇÃO: Usando parse seguro para todos os campos que podem falhar
      idade: safeIntParse(json['idade']),
      sexo: json['sexo'] as String?,
      dataNascimento: json['data_nascimento'] != null
          ? DateTime.tryParse(json['data_nascimento'].toString())
          : null,
      estadoCivil: json['estado_civil'] as String?,
      profissao: json['profissao'] as String?,
      queixaPrincipal: json['queixa_principal'] as String?,
      historicoDoencaAtual: json['historico_doenca_atual'] as String?,
      antecedentesPessoais: json['antecedentes_pessoais'] != null
          ? AntecedentesPessoais.fromJson(json['antecedentes_pessoais'] as Map<String, dynamic>)
          : null,
      historiaFamiliar: json['historia_familiar'] as String?,
      sinaisVitais: json['sinais_vitais'] != null
          ? SinaisVitais.fromJson(json['sinais_vitais'] as Map<String, dynamic>)
          : null,
      nivelConsciencia: json['nivel_consciencia'] as String?,
      estadoNutricional: json['estado_nutricional'] as String?,
      peleMucosas: json['pele_mucosas'] as String?,
      sistemaRespiratorio: json['sistema_respiratorio'] as String?,
      sistemaCardiovascular: json['sistema_cardiovascular'] as String?,
      abdome: json['abdome'] as String?,
      eliminacoesFisiologicas: json['eliminacoes_fisiologicas'] as String?,
      presencaDrenosSondasCateteres: json['drenos_sondas_cateteres'] as String?,
      apoioFamiliarSocial: json['apoio_familiar_social'] as String?,
      necessidadesEmocionaisEspirituais: json['necessidades_emocionais_espirituais'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paciente_id': pacienteId,
      'responsavel_id': responsavelId,
      'nome_paciente': nomePaciente,
      'data_avaliacao': dataAvaliacao.toIso8601String(),
      // Dados pessoais mantidos pois são obrigatórios no backend
      'idade': idade,
      'sexo': sexo,
      'data_nascimento': dataNascimento?.toIso8601String(),
      'estado_civil': estadoCivil,
      'profissao': profissao,
      'queixa_principal': queixaPrincipal,
      'historico_doenca_atual': historicoDoencaAtual,
      'antecedentes_pessoais': (antecedentesPessoais)?.toJson(),
      'historia_familiar': historiaFamiliar,
      'sinais_vitais': (sinaisVitais)?.toJson(),
      'nivel_consciencia': nivelConsciencia,
      'estado_nutricional': estadoNutricional,
      'pele_mucosas': peleMucosas,
      'sistema_respiratorio': sistemaRespiratorio,
      'sistema_cardiovascular': sistemaCardiovascular,
      'abdome': abdome,
      'eliminacoes_fisiologicas': eliminacoesFisiologicas,
      'drenos_sondas_cateteres': presencaDrenosSondasCateteres,
      'apoio_familiar_social': apoioFamiliarSocial,
      'necessidades_emocionais_espirituais': necessidadesEmocionaisEspirituais,
    };
  }
}

@immutable
class AntecedentesPessoais {
  final bool hasHAS;
  final bool hasDM;
  final bool hasCardiopatias;
  final bool hasAsmaDPOC;
  final String? outrasDoencasCronicas;
  final String? cirurgiasAnteriores;
  final String? alergias;
  final String? medicamentosUsoContinuo;
  final bool temTabagismo;
  final bool temEtilismo;
  final bool temSedentarismo;
  final String? outrosHabitos;

  const AntecedentesPessoais({
    this.hasHAS = false,
    this.hasDM = false,
    this.hasCardiopatias = false,
    this.hasAsmaDPOC = false,
    this.outrasDoencasCronicas,
    this.cirurgiasAnteriores,
    this.alergias,
    this.medicamentosUsoContinuo,
    this.temTabagismo = false,
    this.temEtilismo = false,
    this.temSedentarismo = false,
    this.outrosHabitos,
  });

  factory AntecedentesPessoais.fromJson(Map<String, dynamic> json) {
    return AntecedentesPessoais(
      hasHAS: json['has_has'] as bool? ?? false,
      hasDM: json['has_dm'] as bool? ?? false,
      hasCardiopatias: json['has_cardiopatias'] as bool? ?? false,
      hasAsmaDPOC: json['has_asma_dpoc'] as bool? ?? false,
      outrasDoencasCronicas: json['outras_doencas_cronicas'] as String?,
      cirurgiasAnteriores: json['cirurgias_anteriores'] as String?,
      alergias: json['alergias'] as String?,
      medicamentosUsoContinuo: json['medicamentos_uso_continuo'] as String?,
      temTabagismo: json['tem_tabagismo'] as bool? ?? false,
      temEtilismo: json['tem_etilismo'] as bool? ?? false,
      temSedentarismo: json['tem_sedentarismo'] as bool? ?? false,
      outrosHabitos: json['outros_habitos'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'has_has': hasHAS,
      'has_dm': hasDM,
      'has_cardiopatias': hasCardiopatias,
      'has_asma_dpoc': hasAsmaDPOC,
      'outras_doencas_cronicas': outrasDoencasCronicas,
      'cirurgias_anteriores': cirurgiasAnteriores,
      'alergias': alergias,
      'medicamentos_uso_continuo': medicamentosUsoContinuo,
      'tem_tabagismo': temTabagismo,
      'tem_etilismo': temEtilismo,
      'tem_sedentarismo': temSedentarismo,
      'outros_habitos': outrosHabitos,
    };
  }
}

@immutable
class SinaisVitais {
  final String? pressaoArterial;
  final int? frequenciaCardiaca;
  final int? frequenciaRespiratoria;
  final double? temperatura;
  final int? saturacaoO2;

  const SinaisVitais({
    this.pressaoArterial,
    this.frequenciaCardiaca,
    this.frequenciaRespiratoria,
    this.temperatura,
    this.saturacaoO2,
  });

  factory SinaisVitais.fromJson(Map<String, dynamic> json) {
    return SinaisVitais(
      pressaoArterial: json['pa'] as String?,
      frequenciaCardiaca: int.tryParse(json['fc']?.toString() ?? ''),
      frequenciaRespiratoria: int.tryParse(json['fr']?.toString() ?? ''),
      temperatura: double.tryParse(json['temp']?.toString() ?? ''),
      saturacaoO2: int.tryParse(json['spo2']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pa': pressaoArterial,
      'fc': frequenciaCardiaca?.toString(),
      'fr': frequenciaRespiratoria?.toString(),
      'temp': temperatura?.toString(),
      'spo2': saturacaoO2?.toString(),
    };
  }
}