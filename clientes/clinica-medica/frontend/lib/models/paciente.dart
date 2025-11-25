// lib/models/paciente.dart

import 'package:flutter/foundation.dart';

@immutable
class Paciente {
  const Paciente({
    required this.id,
    this.nome,
    this.email,
    this.telefone,
    this.endereco,
    this.dataNascimento,
    this.sexo,
    this.estadoCivil,
    this.profissao,
    this.profileImageUrl, // <-- CAMPO ADICIONADO
  });

  final String id;
  final String? nome;
  final String? email;
  final String? telefone;
  final Map<String, dynamic>? endereco;
  final DateTime? dataNascimento;
  final String? sexo;
  final String? estadoCivil;
  final String? profissao;
  final String? profileImageUrl; // <-- CAMPO ADICIONADO

  factory Paciente.fromJson(Map<String, dynamic> json) {
    return Paciente(
      id: json['id'] as String,
      nome: json['nome'] as String?,
      email: json['email'] as String?,
      telefone: json['telefone'] as String?,
      endereco: json['endereco'] as Map<String, dynamic>?,
      dataNascimento: json['data_nascimento'] != null
          ? DateTime.tryParse(json['data_nascimento'] as String)
          : null,
      sexo: json['sexo'] as String?,
      estadoCivil: json['estado_civil'] as String?,
      profissao: json['profissao'] as String?,
      // LÓGICA PARA PEGAR A URL DA IMAGEM DO BACKEND
      profileImageUrl: json['profile_image_url'] as String?, 
    );
  }
}