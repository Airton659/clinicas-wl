// lib/models/relatorio_medico.dart

import 'package:analicegrubert/models/usuario.dart';

enum StatusRelatorio { pendente, aprovado, recusado }

class RelatorioMedico {
  final String id;
  final String pacienteId;
  final String medicoId;
  final String? criadoPorId; // ID de quem criou o relatório
  final Usuario? paciente;
  final Usuario? medico;
  final Usuario? criadoPor; // Quem criou o relatório (enfermeiro/admin)
  final StatusRelatorio status;
  final DateTime dataCriacao;
  final DateTime? dataAvaliacao;
  final String? motivoRecusa;
  final String? conteudo; // Campo de texto livre do relatório
  final List<String> fotos;

  const RelatorioMedico({
    required this.id,
    required this.pacienteId,
    required this.medicoId,
    this.criadoPorId,
    this.paciente,
    this.medico,
    this.criadoPor,
    required this.status,
    required this.dataCriacao,
    this.dataAvaliacao,
    this.motivoRecusa,
    this.conteudo,
    required this.fotos,
  });

  factory RelatorioMedico.fromJson(Map<String, dynamic> json) {
    final statusString = json['status'] as String? ?? 'pendente';
    StatusRelatorio status;
    
    switch (statusString.toLowerCase()) {
      case 'aprovado':
        status = StatusRelatorio.aprovado;
        break;
      case 'recusado':
        status = StatusRelatorio.recusado;
        break;
      case 'pendente':
      default:
        status = StatusRelatorio.pendente;
        break;
    }

    return RelatorioMedico(
      id: json['id'] as String,
      pacienteId: json['paciente_id'] as String,
      medicoId: json['medico_id'] as String,
      criadoPorId: json['criado_por_id'] as String?,
      paciente: json['paciente'] != null
          ? Usuario.fromJson(json['paciente'] as Map<String, dynamic>)
          : null,
      medico: json['medico'] != null
          ? Usuario.fromJson(json['medico'] as Map<String, dynamic>)
          : null,
      criadoPor: json['criado_por'] != null
          ? Usuario.fromJson(json['criado_por'] as Map<String, dynamic>)
          : null,
      status: status,
      dataCriacao: DateTime.parse(json['data_criacao'] as String),
      dataAvaliacao: json['data_revisao'] != null
          ? DateTime.parse(json['data_revisao'] as String)
          : null,
      motivoRecusa: json['motivo_recusa'] as String?,
      conteudo: json['conteudo'] as String? ?? json['texto'] as String? ?? json['descricao'] as String?,
      fotos: (json['fotos'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'paciente_id': pacienteId,
      'medico_id': medicoId,
      'status': status.name,
      'data_criacao': dataCriacao.toIso8601String(),
      'data_avaliacao': dataAvaliacao?.toIso8601String(),
      'motivo_recusa': motivoRecusa,
      'conteudo': conteudo,
      'fotos': fotos,
    };
  }
}