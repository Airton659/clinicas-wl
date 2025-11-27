import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/negocio.dart';

/// Service para operações de Super Admin (role="platform")
class SuperAdminService {
  final String baseUrl;
  final Future<String?> Function() getToken;

  SuperAdminService({
    required this.baseUrl,
    required this.getToken,
  });

  /// Headers padrão com autenticação
  Future<Map<String, String>> get _headers async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  // ============================================================
  // GESTÃO DE NEGÓCIOS
  // ============================================================

  /// Lista todos os negócios da plataforma
  Future<List<Negocio>> listNegocios() async {
    final url = Uri.parse('$baseUrl/super-admin/negocios');
    final headers = await _headers;
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as List;
      return data.map((json) => Negocio.fromJson(json)).toList();
    } else if (response.statusCode == 403) {
      throw Exception('Acesso negado: Você não é Super Admin');
    } else {
      throw Exception('Erro ao listar negócios: ${response.statusCode}');
    }
  }

  // ============================================================
  // REGISTRO DE ACESSO (AUDITORIA)
  // ============================================================

  /// Registra acesso a dados sensíveis (obrigatório antes de qualquer operação)
  Future<void> requestAccess({
    required String negocioId,
    required String justificativa,
    required String action,
  }) async {
    final url = Uri.parse('$baseUrl/super-admin/access-request');
    final body = json.encode({
      'negocio_id': negocioId,
      'justificativa': justificativa,
      'action': action,
    });
    final headers = await _headers;

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode != 200) {
      throw Exception('Erro ao registrar acesso: ${response.statusCode}');
    }
  }

  /// Busca logs de auditoria
  Future<List<SuperAdminLog>> getAuditLogs({
    String? negocioId,
    String? adminUserId,
    int limit = 100,
  }) async {
    final queryParams = <String, String>{};
    if (negocioId != null) queryParams['negocio_id'] = negocioId;
    if (adminUserId != null) queryParams['admin_user_id'] = adminUserId;
    queryParams['limit'] = limit.toString();

    final url = Uri.parse('$baseUrl/super-admin/audit-logs')
        .replace(queryParameters: queryParams);
    final headers = await _headers;
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as List;
      return data.map((json) => SuperAdminLog.fromJson(json)).toList();
    } else {
      throw Exception('Erro ao buscar logs: ${response.statusCode}');
    }
  }

  // ============================================================
  // GESTÃO DE TERMINOLOGIA CUSTOMIZADA
  // ============================================================

  /// Busca terminologia de um negócio
  Future<CustomTerminology> getTerminology(String negocioId) async {
    final url = Uri.parse('$baseUrl/super-admin/negocios/$negocioId/terminology');
    final headers = await _headers;
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return CustomTerminology.fromJson(data);
    } else if (response.statusCode == 404) {
      // Se não existe, retorna padrão
      return CustomTerminology.defaults;
    } else {
      throw Exception('Erro ao buscar terminologia: ${response.statusCode}');
    }
  }

  /// Atualiza terminologia de um negócio
  Future<void> updateTerminology(
    String negocioId,
    CustomTerminology terminology,
  ) async {
    final url = Uri.parse('$baseUrl/super-admin/negocios/$negocioId/terminology');
    final body = json.encode(terminology.toJson());
    final headers = await _headers;

    final response = await http.put(url, headers: headers, body: body);

    if (response.statusCode != 200) {
      final error = json.decode(utf8.decode(response.bodyBytes));
      throw Exception(error['detail'] ?? 'Erro ao atualizar terminologia');
    }
  }

  /// Reseta terminologia para padrões
  Future<void> resetTerminology(String negocioId) async {
    final url =
        Uri.parse('$baseUrl/super-admin/negocios/$negocioId/reset-terminology');
    final headers = await _headers;
    final response = await http.post(url, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Erro ao resetar terminologia: ${response.statusCode}');
    }
  }

  // ============================================================
  // OPERAÇÕES COMBINADAS (COM AUDITORIA AUTOMÁTICA)
  // ============================================================

  /// Atualiza terminologia COM registro de auditoria
  Future<void> updateTerminologyWithAudit({
    required String negocioId,
    required CustomTerminology terminology,
    required String justificativa,
  }) async {
    // 1. Registrar acesso
    await requestAccess(
      negocioId: negocioId,
      justificativa: justificativa,
      action: 'update_terminology',
    );

    // 2. Atualizar terminologia
    await updateTerminology(negocioId, terminology);
  }

  /// Reseta terminologia COM registro de auditoria
  Future<void> resetTerminologyWithAudit({
    required String negocioId,
    required String justificativa,
  }) async {
    // 1. Registrar acesso
    await requestAccess(
      negocioId: negocioId,
      justificativa: justificativa,
      action: 'reset_terminology',
    );

    // 2. Resetar terminologia
    await resetTerminology(negocioId);
  }
}
