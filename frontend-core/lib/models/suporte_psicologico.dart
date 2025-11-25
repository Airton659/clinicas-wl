// lib/models/suporte_psicologico.dart

import 'package:flutter/foundation.dart';

@immutable
class SuportePsicologico {
  const SuportePsicologico({
    required this.id,
    required this.pacienteId,
    required this.negocioId,
    required this.titulo,
    required this.conteudo,
    required this.tipo,
    required this.criadoPor,
    required this.dataCriacao,
    required this.dataAtualizacao,
  });

  final String id;
  final String pacienteId;
  final String negocioId;
  final String titulo;
  final String conteudo;
  final String tipo; // "link" ou "texto"
  final String criadoPor;
  final DateTime dataCriacao;
  final DateTime dataAtualizacao;

  bool get isLink => tipo == 'link';

  factory SuportePsicologico.fromJson(Map<String, dynamic> json) {
    return SuportePsicologico(
      id: json['id'] as String? ?? '',
      pacienteId: json['paciente_id'] as String? ?? '',
      negocioId: json['negocio_id'] as String? ?? '',
      titulo: json['titulo'] as String? ?? '',
      conteudo: json['conteudo'] as String? ?? '',
      tipo: json['tipo'] as String? ?? 'texto',
      criadoPor: json['criado_por'] as String? ?? '',
      dataCriacao: DateTime.tryParse(json['data_criacao'] as String? ?? '') ?? DateTime.now(),
      dataAtualizacao: DateTime.tryParse(json['data_atualizacao'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'paciente_id': pacienteId,
      'negocio_id': negocioId,
      'titulo': titulo,
      'conteudo': conteudo,
      'tipo': tipo,
      'criado_por': criadoPor,
      'data_criacao': dataCriacao.toIso8601String(),
      'data_atualizacao': dataAtualizacao.toIso8601String(),
    };
  }
}