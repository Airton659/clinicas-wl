// lib/models/exame.dart

import 'package:flutter/foundation.dart';

@immutable
class Exame {
  const Exame({
    required this.id,
    required this.nomeExame,
    required this.dataExame,
    this.horarioExame,
    this.descricao,
    this.urlAnexo,
    this.criadoPor, // Tornado opcional para compatibilidade
    this.dataCriacao, // Tornado opcional para compatibilidade
    this.dataAtualizacao, // Tornado opcional para compatibilidade
  });

  final String id;
  final String nomeExame;
  final DateTime? dataExame;
  final String? horarioExame; // NOVO - horário específico (HH:MM)
  final String? descricao; // NOVO - instruções/observações
  final String? urlAnexo;
  final String? criadoPor; // NOVO - firebase_uid do criador (opcional para compatibilidade)
  final DateTime? dataCriacao; // NOVO - data de criação (opcional para compatibilidade)
  final DateTime? dataAtualizacao; // NOVO - data de atualização (opcional para compatibilidade)

  factory Exame.fromJson(Map<String, dynamic> json) {
    return Exame(
      id: json['id'] as String? ?? '',
      nomeExame: json['nome_exame'] as String? ?? '',
      dataExame: json['data_exame'] != null 
          ? DateTime.tryParse(json['data_exame'] as String)
          : null,
      horarioExame: json['horario_exame'] as String?, // NOVO
      descricao: json['descricao'] as String?, // NOVO
      urlAnexo: json['url_anexo'] as String?,
      criadoPor: json['criado_por'] as String?, // NOVO - pode ser null para exames antigos
      dataCriacao: json['data_criacao'] != null ? DateTime.tryParse(json['data_criacao'] as String) : null, // NOVO
      dataAtualizacao: json['data_atualizacao'] != null ? DateTime.tryParse(json['data_atualizacao'] as String) : null, // NOVO
    );
  }
}