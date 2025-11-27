/// Model para representar um Negócio (empresa) no sistema
class Negocio {
  final String id;
  final String nome;
  final String tipo; // 'clinica-medica', 'clinica-vet', etc.
  final String plano; // 'basic', 'professional', 'enterprise'
  final bool ativo;
  final CustomTerminology? terminologia;
  final DateTime createdAt;
  final int? totalUsuarios;
  final int? totalPacientes;

  Negocio({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.plano,
    this.ativo = true,
    this.terminologia,
    required this.createdAt,
    this.totalUsuarios,
    this.totalPacientes,
  });

  factory Negocio.fromJson(Map<String, dynamic> json) {
    return Negocio(
      id: json['id'] as String,
      nome: json['nome'] as String,
      tipo: json['tipo'] as String? ?? 'clinica-medica',
      plano: json['plano'] as String? ?? 'basic',
      ativo: json['ativo'] as bool? ?? true,
      terminologia: json['terminologia'] != null
          ? CustomTerminology.fromJson(json['terminologia'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      totalUsuarios: json['total_usuarios'] as int?,
      totalPacientes: json['total_pacientes'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'tipo': tipo,
      'plano': plano,
      'ativo': ativo,
      'terminologia': terminologia?.toJson(),
      'created_at': createdAt.toIso8601String(),
      'total_usuarios': totalUsuarios,
      'total_pacientes': totalPacientes,
    };
  }

  /// Copia o objeto com novos valores
  Negocio copyWith({
    String? nome,
    String? tipo,
    String? plano,
    bool? ativo,
    CustomTerminology? terminologia,
    int? totalUsuarios,
    int? totalPacientes,
  }) {
    return Negocio(
      id: id,
      nome: nome ?? this.nome,
      tipo: tipo ?? this.tipo,
      plano: plano ?? this.plano,
      ativo: ativo ?? this.ativo,
      terminologia: terminologia ?? this.terminologia,
      createdAt: createdAt,
      totalUsuarios: totalUsuarios ?? this.totalUsuarios,
      totalPacientes: totalPacientes ?? this.totalPacientes,
    );
  }
}

/// Terminologia customizada para uma empresa
class CustomTerminology {
  final String patient;
  final String consultation;
  final String anamnese;
  final String team;
  final String exam;
  final String medication;
  final String guideline;
  final String diary;
  final String medicalReport;

  CustomTerminology({
    this.patient = 'Paciente',
    this.consultation = 'Consulta',
    this.anamnese = 'Anamnese',
    this.team = 'Equipe',
    this.exam = 'Exame',
    this.medication = 'Medicação',
    this.guideline = 'Orientação',
    this.diary = 'Diário',
    this.medicalReport = 'Relatório Médico',
  });

  factory CustomTerminology.fromJson(Map<String, dynamic> json) {
    return CustomTerminology(
      patient: json['patient'] as String? ?? 'Paciente',
      consultation: json['consultation'] as String? ?? 'Consulta',
      anamnese: json['anamnese'] as String? ?? 'Anamnese',
      team: json['team'] as String? ?? 'Equipe',
      exam: json['exam'] as String? ?? 'Exame',
      medication: json['medication'] as String? ?? 'Medicação',
      guideline: json['guideline'] as String? ?? 'Orientação',
      diary: json['diary'] as String? ?? 'Diário',
      medicalReport: json['medical_report'] as String? ?? 'Relatório Médico',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patient': patient,
      'consultation': consultation,
      'anamnese': anamnese,
      'team': team,
      'exam': exam,
      'medication': medication,
      'guideline': guideline,
      'diary': diary,
      'medical_report': medicalReport,
    };
  }

  /// Retorna terminologia padrão
  static CustomTerminology get defaults => CustomTerminology();

  /// Copia com novos valores
  CustomTerminology copyWith({
    String? patient,
    String? consultation,
    String? anamnese,
    String? team,
    String? exam,
    String? medication,
    String? guideline,
    String? diary,
    String? medicalReport,
  }) {
    return CustomTerminology(
      patient: patient ?? this.patient,
      consultation: consultation ?? this.consultation,
      anamnese: anamnese ?? this.anamnese,
      team: team ?? this.team,
      exam: exam ?? this.exam,
      medication: medication ?? this.medication,
      guideline: guideline ?? this.guideline,
      diary: diary ?? this.diary,
      medicalReport: medicalReport ?? this.medicalReport,
    );
  }
}

/// Request para acesso de Super Admin
class SuperAdminAccessRequest {
  final String negocioId;
  final String justificativa;
  final String action;

  SuperAdminAccessRequest({
    required this.negocioId,
    required this.justificativa,
    required this.action,
  });

  Map<String, dynamic> toJson() {
    return {
      'negocio_id': negocioId,
      'justificativa': justificativa,
      'action': action,
    };
  }
}

/// Log de auditoria do Super Admin
class SuperAdminLog {
  final String id;
  final String adminUserId;
  final String adminEmail;
  final String action;
  final String negocioId;
  final String? resourceId;
  final String justificativa;
  final DateTime timestamp;
  final String? ipAddress;
  final String? userAgent;

  SuperAdminLog({
    required this.id,
    required this.adminUserId,
    required this.adminEmail,
    required this.action,
    required this.negocioId,
    this.resourceId,
    required this.justificativa,
    required this.timestamp,
    this.ipAddress,
    this.userAgent,
  });

  factory SuperAdminLog.fromJson(Map<String, dynamic> json) {
    return SuperAdminLog(
      id: json['id'] as String,
      adminUserId: json['admin_user_id'] as String,
      adminEmail: json['admin_email'] as String,
      action: json['action'] as String,
      negocioId: json['negocio_id'] as String,
      resourceId: json['resource_id'] as String?,
      justificativa: json['justificativa'] as String,
      timestamp: DateTime.parse(json['timestamp']),
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
    );
  }
}
