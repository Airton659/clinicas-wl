// lib/models/usuario.dart

import 'package:flutter/foundation.dart';

@immutable
class Usuario {
  const Usuario({
    this.id,
    required this.firebaseUid,
    this.email,
    this.nome,
    this.roles,
    this.telefone,
    this.endereco,
    this.supervisor_id,
    this.profissional_id,
    this.enfermeiroId,
    this.medicoId,
    this.tecnicosIds,
    this.status_por_negocio,
    this.consentimentoLgpd,
    this.dataConsentimentoLgpd,
    this.tipoConsentimento,
    this.profileImage,
    this.associations,
  });

  final String? id;
  final String firebaseUid;
  final String? email;
  final String? nome;
  final Map<String, dynamic>? roles;
  final String? telefone;
  final Map<String, dynamic>? endereco;
  final String? supervisor_id;
  final String? profissional_id;
  final String? enfermeiroId;
  final String? medicoId;
  final List<String>? tecnicosIds;
  final Map<String, dynamic>? status_por_negocio;
  final bool? consentimentoLgpd;
  final DateTime? dataConsentimentoLgpd;
  final String? tipoConsentimento;
  final String? profileImage;
  final Map<String, List<String>>? associations;

  // Helper para detectar super_admin
  bool get isSuperAdmin => roles?['platform'] == 'super_admin';

  // Helpers para associações dinâmicas
  List<String> getAssociatedProfessionals(String profileId) {
    return associations?[profileId] ?? [];
  }

  bool hasAssociation(String profileId, String userId) {
    return associations?[profileId]?.contains(userId) ?? false;
  }

  int getAssociationCount(String profileId) {
    return associations?[profileId]?.length ?? 0;
  }

  // CONSTRUTOR ADICIONAL PARA CASOS DE FALHA
  const Usuario.empty()
      : id = '',
        firebaseUid = '',
        email = 'Desconhecido',
        nome = 'Usuário Desconhecido',
        roles = const {},
        telefone = null,
        endereco = null,
        supervisor_id = null,
        profissional_id = null,
        enfermeiroId = null,
        medicoId = null,
        tecnicosIds = null,
        status_por_negocio = null,
        consentimentoLgpd = null,
        dataConsentimentoLgpd = null,
        tipoConsentimento = null,
        profileImage = null,
        associations = null;

  static Map<String, List<String>>? _parseAssociations(dynamic data) {
    if (data == null) return null;

    final Map<String, List<String>> result = {};
    (data as Map<String, dynamic>).forEach((key, value) {
      result[key] = value != null ? List<String>.from(value) : [];
    });

    return result;
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    final firebaseUid = json['firebase_uid'] as String? ?? json['id'] as String? ?? '';

    return Usuario(
      id: json['id'] as String?,
      firebaseUid: firebaseUid,
      email: json['email'] as String?,
      nome: json['nome'] as String?,
      roles: json['roles'] as Map<String, dynamic>?,
      telefone: json['telefone'] as String?,
      endereco: json['endereco'] as Map<String, dynamic>?,
      supervisor_id: json['supervisor_id'] as String?,
      profissional_id: json['profissional_id'] as String?,
      
      // *** CORREÇÃO APLICADA CONFORME RELATÓRIO DO BACKEND ***
      enfermeiroId: json['enfermeiro_vinculado_id'] as String?,
      medicoId: (json['medico_id'] ?? json['medico_vinculado_id']) as String?, // BREAKING CHANGE - SUPORTE AMBOS
      tecnicosIds: json['tecnicos_vinculados_ids'] != null
          ? List<String>.from(json['tecnicos_vinculados_ids'])
          : null,

      status_por_negocio: json['status_por_negocio'] as Map<String, dynamic>?,
      consentimentoLgpd: json['consentimento_lgpd'] as bool?,
      dataConsentimentoLgpd: json['data_consentimento_lgpd'] != null 
          ? DateTime.tryParse(json['data_consentimento_lgpd'] as String)
          : null,
      tipoConsentimento: json['tipo_consentimento'] as String?,
      profileImage: json['profile_image_url'] as String? ?? json['profile_image'] as String?,
      associations: _parseAssociations(json['associations']),
    );
  }
}