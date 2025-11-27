class Role {
  final String? id;
  final String negocioId;
  final String tipo;
  final int nivelHierarquico;

  final String nomeCustomizado;
  final String? descricaoCustomizada;
  final String? cor;
  final String? icone;

  final List<String> permissions;

  final bool isActive;
  final bool isSystem;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Role({
    this.id,
    required this.negocioId,
    required this.tipo,
    required this.nivelHierarquico,
    required this.nomeCustomizado,
    this.descricaoCustomizada,
    this.cor = '#2196F3',
    this.icone = 'person',
    this.permissions = const [],
    this.isActive = true,
    this.isSystem = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] as String?,
      negocioId: (json['negocio_id'] as String?) ?? '',
      tipo: (json['tipo'] as String?) ?? 'custom',
      nivelHierarquico: (json['nivel_hierarquico'] as int?) ?? 50,
      nomeCustomizado: (json['nome_customizado'] as String?) ?? 'Sem Nome',
      descricaoCustomizada: json['descricao_customizada'] as String?,
      cor: json['cor'] as String? ?? '#2196F3',
      icone: json['icone'] as String? ?? 'person',
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isActive: json['is_active'] as bool? ?? true,
      isSystem: json['is_system'] as bool? ?? false,
      createdAt: json['created_at'] != null && json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null && json['updated_at'] is String
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'negocio_id': negocioId,
      'tipo': tipo,
      'nivel_hierarquico': nivelHierarquico,
      'nome_customizado': nomeCustomizado,
      if (descricaoCustomizada != null)
        'descricao_customizada': descricaoCustomizada,
      'cor': cor,
      'icone': icone,
      'permissions': permissions,
      'is_active': isActive,
      'is_system': isSystem,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Role copyWith({
    String? id,
    String? negocioId,
    String? tipo,
    int? nivelHierarquico,
    String? nomeCustomizado,
    String? descricaoCustomizada,
    String? cor,
    String? icone,
    List<String>? permissions,
    bool? isActive,
    bool? isSystem,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Role(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      tipo: tipo ?? this.tipo,
      nivelHierarquico: nivelHierarquico ?? this.nivelHierarquico,
      nomeCustomizado: nomeCustomizado ?? this.nomeCustomizado,
      descricaoCustomizada: descricaoCustomizada ?? this.descricaoCustomizada,
      cor: cor ?? this.cor,
      icone: icone ?? this.icone,
      permissions: permissions ?? this.permissions,
      isActive: isActive ?? this.isActive,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Role(id: $id, nomeCustomizado: $nomeCustomizado, tipo: $tipo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Role && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
