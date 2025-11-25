// lib/models/tarefa_agendada.dart

import 'package:analicegrubert/models/usuario.dart';

enum StatusTarefa { pendente, concluida, atrasada }

class TarefaAgendada {
  final String id;
  final String descricao;
  final DateTime dataHoraLimite;
  final bool foiConcluida;
  final DateTime? dataConclusao;
  final Usuario? criadoPor;
  final Usuario? executadoPor;

  const TarefaAgendada({
    required this.id,
    required this.descricao,
    required this.dataHoraLimite,
    required this.foiConcluida,
    this.dataConclusao,
    this.criadoPor,
    this.executadoPor,
  });

  // Lógica para determinar o status atual da tarefa
  StatusTarefa get status {
    if (foiConcluida) {
      return StatusTarefa.concluida;
    }
    if (DateTime.now().isAfter(dataHoraLimite)) {
      return StatusTarefa.atrasada;
    }
    return StatusTarefa.pendente;
  }

  factory TarefaAgendada.fromJson(Map<String, dynamic> json) {
    return TarefaAgendada(
      id: json['id'] as String,
      descricao: json['descricao'] as String,
      dataHoraLimite: DateTime.parse(
        json['dataHoraLimite'] ?? json['data_hora_limite'] as String
      ).toLocal(), // Converte UTC para horário local
      foiConcluida: json['foiConcluida'] ?? json['foi_concluida'] as bool? ?? false,
      dataConclusao: (json['dataConclusao'] ?? json['data_conclusao']) != null
          ? DateTime.parse((json['dataConclusao'] ?? json['data_conclusao']) as String).toLocal()
          : null,
      criadoPor: (json['criadoPor'] ?? json['criado_por']) != null
          ? Usuario.fromJson((json['criadoPor'] ?? json['criado_por']) as Map<String, dynamic>)
          : null,
      executadoPor: (json['executadoPor'] ?? json['executado_por']) != null
          ? Usuario.fromJson((json['executadoPor'] ?? json['executado_por']) as Map<String, dynamic>)
          : null,
    );
  }
}