// lib/models/consulta.dart

import 'package:flutter/foundation.dart';

@immutable
class Consulta {
  const Consulta({
    required this.id,
    required this.dataConsulta,
    required this.resumo,
    this.medicoId,
  });

  final String id;
  final DateTime dataConsulta;
  final String resumo;
  final String? medicoId;

  factory Consulta.fromJson(Map<String, dynamic> json) {
    return Consulta(
      id: json['id'] as String? ?? '',
      dataConsulta: json['data_consulta'] != null
          ? DateTime.parse(json['data_consulta'] as String)
          : DateTime.now(), // Fornece um valor padrão
      resumo: json['resumo'] as String? ?? '',
      medicoId: json['medico_id'] as String?,
    );
  }
}