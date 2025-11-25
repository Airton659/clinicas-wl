// lib/models/ficha_completa.dart

import 'package:analicegrubert/models/checklist_item.dart';
import 'package:analicegrubert/models/consulta.dart';
import 'package:analicegrubert/models/medicacao.dart';
import 'package:analicegrubert/models/orientacao.dart';
import 'package:analicegrubert/models/prontuario.dart';
import 'package:flutter/foundation.dart';

@immutable
class FichaCompleta {
  const FichaCompleta({
    required this.consultas,
    required this.medicacoes,
    required this.checklist,
    required this.orientacoes,
    required this.prontuarios,
  });

  final List<Consulta> consultas;
  final List<Medicacao> medicacoes;
  final List<ChecklistItem> checklist;
  final List<Orientacao> orientacoes;
  final List<Prontuario> prontuarios;

  factory FichaCompleta.fromJson(Map<String, dynamic> json) {
    return FichaCompleta(
      consultas: (json['consultas'] as List<dynamic>? ?? [])
          .map((e) => Consulta.fromJson(e as Map<String, dynamic>))
          .toList(),
      medicacoes: (json['medicacoes'] as List<dynamic>? ?? [])
          .map((e) => Medicacao.fromJson(e as Map<String, dynamic>))
          .toList(),
      checklist: (json['checklist'] as List<dynamic>? ?? [])
          .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      orientacoes: (json['orientacoes'] as List<dynamic>? ?? [])
          .map((e) => Orientacao.fromJson(e as Map<String, dynamic>))
          .toList(),
      prontuarios: (json['prontuarios'] as List<dynamic>? ?? [])
          .map((e) => Prontuario.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}