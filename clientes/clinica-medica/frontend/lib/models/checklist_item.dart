// lib/models/checklist_item.dart

import 'package:flutter/foundation.dart';

@immutable
class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.descricaoItem,
    required this.concluido,
  });

  final String id;
  final String descricaoItem;
  final bool concluido;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      // CORREÇÃO: Verifica se 'descricao_item' existe, caso contrário, usa 'descricao'
      descricaoItem: (json['descricao_item'] as String? ?? json['descricao'] as String?) ?? '',
      concluido: json['concluido'] as bool,
    );
  }
}