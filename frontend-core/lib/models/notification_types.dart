// lib/models/notification_types.dart

enum NotificationType {
  // ✅ NOTIFICAÇÕES ATIVAS (9)
  relatorioAvaliado('RELATORIO_AVALIADO'),
  planoAtualizado('PLANO_ATUALIZADO'),
  associacaoProfissional('ASSOCIACAO_PACIENTE'),
  novoRelatorioMedico('NOVO_RELATORIO_MEDICO'),
  tarefaConcluida('TAREFA_CONCLUIDA'),
  tarefaAtrasada('TAREFA_ATRASADA'),
  tarefaAtrasadaTecnico('TAREFA_ATRASADA_TECNICO'),
  lembreteExame('LEMBRETE_EXAME'),
  exameCriado('EXAME_CRIADO');

  // ❌ NOTIFICAÇÕES DESABILITADAS (não usar mais)
  // checklistConcluido('CHECKLIST_CONCLUIDO'),
  // novoAgendamento('NOVO_AGENDAMENTO'),
  // agendamentoCancelado('AGENDAMENTO_CANCELADO'),
  // lembretePersonalizado('LEMBRETE_PERSONALIZADO'),
  // novoRegistroDiario('NOVO_REGISTRO_DIARIO'),
  // suporteAdicionado('SUPORTE_ADICIONADO');

  const NotificationType(this.value);
  final String value;

  static NotificationType? fromString(String value) {
    for (var type in NotificationType.values) {
      if (type.value == value) {
        return type;
      }
    }
    return null;
  }
}

class NotificationData {
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic> data;

  NotificationData({
    required this.title,
    required this.body,
    required this.type,
    required this.data,
  });

  factory NotificationData.fromMap(Map<String, dynamic> map) {
    return NotificationData(
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: NotificationType.fromString(map['tipo'] ?? '') ?? NotificationType.relatorioAvaliado,
      data: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'tipo': type.value,
      ...data,
    };
  }

  String toJson() {
    return '{"title":"$title","body":"$body","tipo":"${type.value}","data":${data.toString()}}';
  }

  static NotificationData fromJson(String json) {
    // Implementação simples para recuperar dados básicos
    final map = <String, dynamic>{};
    if (json.contains('title')) {
      final titleMatch = RegExp(r'"title":"([^"]*)"').firstMatch(json);
      if (titleMatch != null) map['title'] = titleMatch.group(1);
    }
    if (json.contains('body')) {
      final bodyMatch = RegExp(r'"body":"([^"]*)"').firstMatch(json);
      if (bodyMatch != null) map['body'] = bodyMatch.group(1);
    }
    if (json.contains('tipo')) {
      final tipoMatch = RegExp(r'"tipo":"([^"]*)"').firstMatch(json);
      if (tipoMatch != null) map['tipo'] = tipoMatch.group(1);
    }
    return NotificationData.fromMap(map);
  }
}

class RelatorioAvaliadoNotification {
  final String relatorioId;
  final String pacienteId;
  final String status; // 'aprovado' ou 'recusado'

  RelatorioAvaliadoNotification({
    required this.relatorioId,
    required this.pacienteId,
    required this.status,
  });

  factory RelatorioAvaliadoNotification.fromData(Map<String, dynamic> data) {
    return RelatorioAvaliadoNotification(
      relatorioId: data['relatorio_id'] ?? '',
      pacienteId: data['paciente_id'] ?? '',
      status: data['status'] ?? '',
    );
  }
}

class PlanoAtualizadoNotification {
  final String pacienteId;
  final String consultaId;

  PlanoAtualizadoNotification({
    required this.pacienteId,
    required this.consultaId,
  });

  factory PlanoAtualizadoNotification.fromData(Map<String, dynamic> data) {
    return PlanoAtualizadoNotification(
      pacienteId: data['paciente_id'] ?? '',
      consultaId: data['consulta_id'] ?? '',
    );
  }
}

class AssociacaoProfissionalNotification {
  final String pacienteId;

  AssociacaoProfissionalNotification({
    required this.pacienteId,
  });

  factory AssociacaoProfissionalNotification.fromData(Map<String, dynamic> data) {
    return AssociacaoProfissionalNotification(
      pacienteId: data['paciente_id'] ?? '',
    );
  }
}

// ❌ DESABILITADO - Não usar mais
// class ChecklistConcluidoNotification {
//   final String pacienteId;
//   final String tecnicoId;
//   final String data;
//
//   ChecklistConcluidoNotification({
//     required this.pacienteId,
//     required this.tecnicoId,
//     required this.data,
//   });
//
//   factory ChecklistConcluidoNotification.fromData(Map<String, dynamic> data) {
//     return ChecklistConcluidoNotification(
//       pacienteId: data['paciente_id'] ?? '',
//       tecnicoId: data['tecnico_id'] ?? '',
//       data: data['data'] ?? '',
//     );
//   }
// }

class TarefaAtrasadaNotification {
  final String tarefaId;
  final String pacienteId;
  final String tecnicoId;
  final String titulo;
  final String dataHoraLimite;

  TarefaAtrasadaNotification({
    required this.tarefaId,
    required this.pacienteId,
    required this.tecnicoId,
    required this.titulo,
    required this.dataHoraLimite,
  });

  factory TarefaAtrasadaNotification.fromData(Map<String, dynamic> data) {
    return TarefaAtrasadaNotification(
      tarefaId: data['tarefa_id'] ?? '',
      pacienteId: data['paciente_id'] ?? '',
      tecnicoId: data['tecnico_id'] ?? '',
      titulo: data['titulo'] ?? '',
      dataHoraLimite: data['data_hora_limite'] ?? '',
    );
  }
}

class TarefaAtrasadaTecnicoNotification {
  final String tarefaId;
  final String pacienteId;

  TarefaAtrasadaTecnicoNotification({
    required this.tarefaId,
    required this.pacienteId,
  });

  factory TarefaAtrasadaTecnicoNotification.fromData(Map<String, dynamic> data) {
    final relacionado = data['relacionado'] as Map<String, dynamic>? ?? {};
    return TarefaAtrasadaTecnicoNotification(
      tarefaId: relacionado['tarefa_id'] ?? '',
      pacienteId: relacionado['paciente_id'] ?? '',
    );
  }
}

class LembreteExameNotification {
  final String exameId;
  final String pacienteId;
  final String nomeExame;
  final String dataExame;
  final String? horarioExame;

  LembreteExameNotification({
    required this.exameId,
    required this.pacienteId,
    required this.nomeExame,
    required this.dataExame,
    this.horarioExame,
  });

  factory LembreteExameNotification.fromData(Map<String, dynamic> data) {
    return LembreteExameNotification(
      exameId: data['exame_id'] ?? '',
      pacienteId: data['paciente_id'] ?? '',
      nomeExame: data['nome_exame'] ?? '',
      dataExame: data['data_exame'] ?? '',
      horarioExame: data['horario_exame'],
    );
  }
}

class ExameCriadoNotification {
  final String exameId;
  final String pacienteId;

  ExameCriadoNotification({
    required this.exameId,
    required this.pacienteId,
  });

  factory ExameCriadoNotification.fromData(Map<String, dynamic> data) {
    return ExameCriadoNotification(
      exameId: data['exame_id'] ?? '',
      pacienteId: data['paciente_id'] ?? '',
    );
  }
}

// ❌ DESABILITADO - Não usar mais
// class SuporteAdicionadoNotification {
//   final String suporteId;
//   final String pacienteId;
//
//   SuporteAdicionadoNotification({
//     required this.suporteId,
//     required this.pacienteId,
//   });
//
//   factory SuporteAdicionadoNotification.fromData(Map<String, dynamic> data) {
//     return SuporteAdicionadoNotification(
//       suporteId: data['suporte_id'] ?? '',
//       pacienteId: data['paciente_id'] ?? '',
//     );
//   }
// }

// ❌ DESABILITADO - Não usar mais
// class NovoAgendamentoNotification {
//   final String agendamentoId;
//   final String pacienteId;
//
//   NovoAgendamentoNotification({
//     required this.agendamentoId,
//     required this.pacienteId,
//   });
//
//   factory NovoAgendamentoNotification.fromData(Map<String, dynamic> data) {
//     return NovoAgendamentoNotification(
//       agendamentoId: data['agendamento_id'] ?? '',
//       pacienteId: data['paciente_id'] ?? '',
//     );
//   }
// }

// ❌ DESABILITADO - Não usar mais
// class AgendamentoCanceladoNotification {
//   final String agendamentoId;
//   final String pacienteId;
//
//   AgendamentoCanceladoNotification({
//     required this.agendamentoId,
//     required this.pacienteId,
//   });
//
//   factory AgendamentoCanceladoNotification.fromData(Map<String, dynamic> data) {
//     return AgendamentoCanceladoNotification(
//       agendamentoId: data['agendamento_id'] ?? '',
//       pacienteId: data['paciente_id'] ?? '',
//     );
//   }
// }

// ❌ DESABILITADO - Não usar mais
// class LembretePersonalizadoNotification {
//   final String lembreteId;
//   final String pacienteId;
//
//   LembretePersonalizadoNotification({
//     required this.lembreteId,
//     required this.pacienteId,
//   });
//
//   factory LembretePersonalizadoNotification.fromData(Map<String, dynamic> data) {
//     return LembretePersonalizadoNotification(
//       lembreteId: data['lembrete_id'] ?? '',
//       pacienteId: data['paciente_id'] ?? '',
//     );
//   }
// }

class NovoRelatorioMedicoNotification {
  final String relatorioId;
  final String pacienteId;

  NovoRelatorioMedicoNotification({
    required this.relatorioId,
    required this.pacienteId,
  });

  factory NovoRelatorioMedicoNotification.fromData(Map<String, dynamic> data) {
    return NovoRelatorioMedicoNotification(
      relatorioId: data['relatorio_id'] ?? '',
      pacienteId: data['paciente_id'] ?? '',
    );
  }
}

// ❌ DESABILITADO - Não usar mais
// class NovoRegistroDiarioNotification {
//   final String registroId;
//   final String pacienteId;
//
//   NovoRegistroDiarioNotification({
//     required this.registroId,
//     required this.pacienteId,
//   });
//
//   factory NovoRegistroDiarioNotification.fromData(Map<String, dynamic> data) {
//     return NovoRegistroDiarioNotification(
//       registroId: data['registro_id'] ?? '',
//       pacienteId: data['paciente_id'] ?? '',
//     );
//   }
// }

class TarefaConcluidaNotification {
  final String tarefaId;
  final String pacienteId;

  TarefaConcluidaNotification({
    required this.tarefaId,
    required this.pacienteId,
  });

  factory TarefaConcluidaNotification.fromData(Map<String, dynamic> data) {
    return TarefaConcluidaNotification(
      tarefaId: data['tarefa_id'] ?? '',
      pacienteId: data['paciente_id'] ?? '',
    );
  }
}