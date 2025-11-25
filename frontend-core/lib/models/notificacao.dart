// lib/models/notificacao.dart

class Notificacao {
  final String id;
  final String title;
  final String body;
  final String? tipo;
  final bool lida;
  final DateTime dataCriacao;
  final Map<String, dynamic>? relacionado;
  final String? dedupeKey;

  const Notificacao({
    required this.id,
    required this.title,
    required this.body,
    this.tipo,
    required this.lida,
    required this.dataCriacao,
    this.relacionado,
    this.dedupeKey,
  });

  factory Notificacao.fromJson(Map<String, dynamic> json) {
    // Aceita tanto formato antigo (title/body/data_criacao) quanto novo (titulo/mensagem/criada_em)
    final title = (json['title'] ?? json['titulo'] ?? '') as String;
    final body = (json['body'] ?? json['mensagem'] ?? '') as String;

    // Tenta parsear data_criacao ou criada_em
    final dataString = (json['data_criacao'] ?? json['criada_em']) as String?;
    final dataCriacao = dataString != null
        ? DateTime.parse(dataString)
        : DateTime.now();

    return Notificacao(
      id: json['id'] as String,
      title: title,
      body: body,
      tipo: json['tipo'] as String?,
      lida: json['lida'] as bool? ?? false,
      dataCriacao: dataCriacao,
      relacionado: json['relacionado'] as Map<String, dynamic>?,
      dedupeKey: json['dedupe_key'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'tipo': tipo,
      'lida': lida,
      'data_criacao': dataCriacao.toIso8601String(),
      'relacionado': relacionado,
      'dedupe_key': dedupeKey,
    };
  }

  Notificacao copyWith({
    String? id,
    String? title,
    String? body,
    String? tipo,
    bool? lida,
    DateTime? dataCriacao,
    Map<String, dynamic>? relacionado,
    String? dedupeKey,
  }) {
    return Notificacao(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      tipo: tipo ?? this.tipo,
      lida: lida ?? this.lida,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      relacionado: relacionado ?? this.relacionado,
      dedupeKey: dedupeKey ?? this.dedupeKey,
    );
  }
}

enum TipoNotificacao {
  // ✅ NOTIFICAÇÕES ATIVAS (9)
  relatorioAvaliado('RELATORIO_AVALIADO'),
  planoAtualizado('PLANO_ATUALIZADO'),
  associacaoProfissional('ASSOCIACAO_PROFISSIONAL'),
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

  const TipoNotificacao(this.value);
  final String value;
}