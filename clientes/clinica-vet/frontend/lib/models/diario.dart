// lib/models/diario.dart - VERSÃO CORRIGIDA

import 'package:analicegrubert/models/usuario.dart';
import 'package:flutter/foundation.dart';

@immutable
class Tecnico {
  final String? id; // Tornar opcional
  final String nome;
  final String email;

  const Tecnico({
    required this.id, // Requerer agora é o ID
    required this.nome,
    required this.email,
  });

  factory Tecnico.fromJson(Map<String, dynamic> json) {
    return Tecnico(
      id: json['id'] as String?,
      nome: json['nome'] as String? ?? 'Desconhecido',
      email: json['email'] as String? ?? 'Desconhecido',
    );
  }
}

@immutable
class Diario {
  final String id;
  final DateTime dataOcorrencia;
  final Tecnico tecnico;
  final String? anotacaoGeral;
  final Map<String, dynamic>? medicamentos;
  final Map<String, dynamic>? atividades;
  final Map<String, dynamic>? intercorrencias;

  String get text => anotacaoGeral ?? '';
  DateTime get createdAt => dataOcorrencia;
  String get createdBy => tecnico.id ?? ''; // Corrigido para lidar com ID nulo

  const Diario({
    required this.id,
    required this.dataOcorrencia,
    required this.tecnico,
    this.anotacaoGeral,
    this.medicamentos,
    this.atividades,
    this.intercorrencias,
  });

  factory Diario.fromJson(Map<String, dynamic> json) {
    return Diario(
      id: json['id'] as String,
      dataOcorrencia: DateTime.parse(json['data_ocorrencia'] as String),
      tecnico: Tecnico.fromJson(json['tecnico'] as Map<String, dynamic>),
      anotacaoGeral: json['anotacao_geral'] as String?,
      medicamentos: json['medicamentos'] as Map<String, dynamic>?,
      atividades: json['atividades'] as Map<String, dynamic>?,
      intercorrencias: json['intercorrencias'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'data_ocorrencia': dataOcorrencia.toIso8601String(),
      'tecnico': {
        'id': tecnico.id,
        'nome': tecnico.nome,
        'email': tecnico.email,
      },
      'anotacao_geral': anotacaoGeral,
      'medicamentos': medicamentos,
      'atividades': atividades,
      'intercorrencias': intercorrencias,
    };
  }
}