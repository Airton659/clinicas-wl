// lib/models/medicacao.dart

import 'package:flutter/foundation.dart';

@immutable
class Medicacao {
  const Medicacao({
    required this.id,
    required this.nomeMedicamento,
    required this.dosagem,
    required this.instrucoes,
  });

  final String id;
  final String nomeMedicamento;
  final String dosagem;
  final String instrucoes;

  factory Medicacao.fromJson(Map<String, dynamic> json) {
    return Medicacao(
      id: json['id'] as String? ?? '', // Adiciona verificação nula
      nomeMedicamento: json['nome_medicamento'] as String? ?? '', // Adiciona verificação nula
      dosagem: json['dosagem'] as String? ?? '', // Adiciona verificação nula
      instrucoes: json['instrucoes'] as String? ?? '', // Adiciona verificação nula
    );
  }
}