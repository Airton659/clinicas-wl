import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/permission.dart';
import '../models/role.dart';

class PermissionsService {
  final String baseUrl;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  PermissionsService({required this.baseUrl});

  /// Retorna token de autenticação
  Future<String> _getAuthToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado');
    }
    return await user.getIdToken() ?? '';
  }

  /// Headers com autenticação e negocio_id
  Future<Map<String, String>> _getHeaders(String negocioId) async {
    final token = await _getAuthToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'x-negocio-id': negocioId,
    };
  }

  // ============================================================================
  // PERMISSÕES
  // ============================================================================

  /// Lista todas as permissões disponíveis no sistema
  Future<List<Permission>> listarPermissoes({String? categoria}) async {
    try {
      final token = await _getAuthToken();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      String url = '$baseUrl/permissions';
      if (categoria != null) {
        url += '?categoria=$categoria';
      }

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Permission.fromJson(json)).toList();
      } else {
        throw Exception('Erro ao listar permissões: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro ao listar permissões: $e');
    }
  }

  /// Lista permissões agrupadas por categoria
  Future<Map<String, List<Permission>>> listarPermissoesPorCategoria() async {
    try {
      final token = await _getAuthToken();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/permissions/by-category'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, List<Permission>> result = {};

        data.forEach((categoria, permsList) {
          result[categoria] = (permsList as List)
              .map((json) => Permission.fromJson(json))
              .toList();
        });

        return result;
      } else {
        throw Exception(
            'Erro ao listar permissões por categoria: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro ao listar permissões por categoria: $e');
    }
  }

  /// Lista permissões de um usuário específico
  Future<List<Permission>> listarPermissoesUsuario(
    String negocioId,
    String userId,
  ) async {
    try {
      final headers = await _getHeaders(negocioId);

      final response = await http.get(
        Uri.parse(
            '$baseUrl/negocios/$negocioId/usuarios/$userId/permissions'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> perms = data['permissions'];
        return perms.map((json) => Permission.fromJson(json)).toList();
      } else {
        throw Exception(
            'Erro ao listar permissões do usuário: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro ao listar permissões do usuário: $e');
    }
  }

  // ============================================================================
  // ROLES (PERFIS)
  // ============================================================================

  /// Lista todos os roles de um negócio
  Future<List<Role>> listarRoles(String negocioId) async {
    try {
      final headers = await _getHeaders(negocioId);

      final response = await http.get(
        Uri.parse('$baseUrl/negocios/$negocioId/roles'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> rolesList = data['roles'];
        return rolesList.map((json) => Role.fromJson(json)).toList();
      } else {
        throw Exception('Erro ao listar roles: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro ao listar roles: $e');
    }
  }

  /// Obtém detalhes de um role específico
  Future<Role> obterRole(String negocioId, String roleId) async {
    try {
      final headers = await _getHeaders(negocioId);

      final response = await http.get(
        Uri.parse('$baseUrl/negocios/$negocioId/roles/$roleId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Role.fromJson(data);
      } else {
        throw Exception('Erro ao obter role: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro ao obter role: $e');
    }
  }

  /// Cria novo role
  Future<Role> criarRole(
    String negocioId, {
    required String tipo,
    required int nivelHierarquico,
    required String nomeCustomizado,
    String? descricaoCustomizada,
    String? cor,
    String? icone,
    List<String> permissions = const [],
  }) async {
    try {
      final headers = await _getHeaders(negocioId);

      final body = json.encode({
        'tipo': tipo,
        'nivel_hierarquico': nivelHierarquico,
        'nome_customizado': nomeCustomizado,
        if (descricaoCustomizada != null)
          'descricao_customizada': descricaoCustomizada,
        if (cor != null) 'cor': cor,
        if (icone != null) 'icone': icone,
        'permissions': permissions,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/negocios/$negocioId/roles'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return Role.fromJson(data);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Erro ao criar role');
      }
    } catch (e) {
      throw Exception('Erro ao criar role: $e');
    }
  }

  /// Atualiza role existente
  Future<Role> atualizarRole(
    String negocioId,
    String roleId, {
    String? nomeCustomizado,
    String? descricaoCustomizada,
    String? cor,
    String? icone,
    List<String>? permissions,
    bool? isActive,
  }) async {
    try {
      final headers = await _getHeaders(negocioId);

      final body = json.encode({
        if (nomeCustomizado != null) 'nome_customizado': nomeCustomizado,
        if (descricaoCustomizada != null)
          'descricao_customizada': descricaoCustomizada,
        if (cor != null) 'cor': cor,
        if (icone != null) 'icone': icone,
        if (permissions != null) 'permissions': permissions,
        if (isActive != null) 'is_active': isActive,
      });

      final response = await http.patch(
        Uri.parse('$baseUrl/negocios/$negocioId/roles/$roleId'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Role.fromJson(data);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Erro ao atualizar role');
      }
    } catch (e) {
      throw Exception('Erro ao atualizar role: $e');
    }
  }

  /// Exclui role
  Future<void> excluirRole(String negocioId, String roleId) async {
    try {
      final headers = await _getHeaders(negocioId);

      final response = await http.delete(
        Uri.parse('$baseUrl/negocios/$negocioId/roles/$roleId'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Erro ao excluir role');
      }
    } catch (e) {
      throw Exception('Erro ao excluir role: $e');
    }
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  /// Verifica se usuário tem permissão específica (verificação local)
  bool temPermissao(List<String> userPermissions, String permission) {
    return userPermissions.contains(permission);
  }

  /// Verifica se usuário tem alguma das permissões listadas
  bool temAlgumaPermissao(
      List<String> userPermissions, List<String> permissions) {
    return permissions.any((p) => userPermissions.contains(p));
  }

  /// Verifica se usuário tem todas as permissões listadas
  bool temTodasPermissoes(
      List<String> userPermissions, List<String> permissions) {
    return permissions.every((p) => userPermissions.contains(p));
  }
}
