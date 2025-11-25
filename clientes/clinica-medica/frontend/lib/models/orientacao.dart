// lib/models/orientacao.dart

import 'package:flutter/foundation.dart';

@immutable
class Orientacao {
  const Orientacao({
    required this.id,
    required this.titulo,
    required this.conteudo,
  });

  final String id;
  final String titulo;
  final String conteudo;

  factory Orientacao.fromJson(Map<String, dynamic> json) {
    return Orientacao(
      id: json['id'] as String? ?? '',
      titulo: json['titulo'] as String? ?? '',
      conteudo: json['conteudo'] as String? ?? '',
    );
  }
}