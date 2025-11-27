class Permission {
  final String id;
  final String categoria;
  final String nome;
  final String descricao;
  final String recurso;
  final String acao;

  Permission({
    required this.id,
    required this.categoria,
    required this.nome,
    required this.descricao,
    required this.recurso,
    required this.acao,
  });

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      id: json['id'] as String,
      categoria: json['categoria'] as String,
      nome: json['nome'] as String,
      descricao: json['descricao'] as String,
      recurso: json['recurso'] as String,
      acao: json['acao'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoria': categoria,
      'nome': nome,
      'descricao': descricao,
      'recurso': recurso,
      'acao': acao,
    };
  }

  @override
  String toString() {
    return 'Permission(id: $id, nome: $nome, categoria: $categoria)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Permission && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
