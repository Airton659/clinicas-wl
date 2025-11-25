// lib/models/prontuario.dart

import 'package:flutter/foundation.dart';

@immutable
class Prontuario {
  const Prontuario({
    required this.id,
    required this.data,
    required this.texto,
    required this.tecnicoNome,
  });

  final String id;
  final DateTime data;
  final String texto;
  final String? tecnicoNome;

  // Getters para compatibilidade com código antigo
  String get titulo => tecnicoNome ?? 'Prontuário';
  String get conteudo => texto;
  DateTime get createdAt => data;
  DateTime get updatedAt => data;

  factory Prontuario.fromJson(Map<String, dynamic> json) {
    return Prontuario(
      id: json['id'] as String,
      data: DateTime.parse(json['data_registro'] as String).toLocal(),
      texto: (json['conteudo'] as Map<String, dynamic>)['descricao'] as String,
      tecnicoNome: (json['tecnico'] as Map<String, dynamic>?)?['nome'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'data': data.toIso8601String(),
      'texto': texto,
      'tecnico_nome': tecnicoNome,
    };
  }
}