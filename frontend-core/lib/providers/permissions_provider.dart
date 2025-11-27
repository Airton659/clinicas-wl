import 'package:flutter/foundation.dart';
import '../models/permission.dart';
import '../models/role.dart';
import '../services/permissions_service.dart';

class PermissionsProvider with ChangeNotifier {
  final PermissionsService _permissionsService;

  // Estado
  List<Permission> _userPermissions = [];
  List<Permission> _allPermissions = [];
  Map<String, List<Permission>> _permissionsByCategory = {};
  List<Role> _negocioRoles = [];
  bool _isLoading = false;
  String? _error;

  PermissionsProvider(this._permissionsService);

  // Getters
  List<Permission> get userPermissions => _userPermissions;
  List<Permission> get allPermissions => _allPermissions;
  Map<String, List<Permission>> get permissionsByCategory => _permissionsByCategory;
  List<Role> get negocioRoles => _negocioRoles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ============================================================================
  // CARREGAR DADOS
  // ============================================================================

  /// Carrega todas as permissões do sistema
  Future<void> carregarTodasPermissoes() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _allPermissions = await _permissionsService.listarPermissoes();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Carrega permissões agrupadas por categoria
  Future<void> carregarPermissoesPorCategoria() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _permissionsByCategory = await _permissionsService.listarPermissoesPorCategoria();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Carrega permissões do usuário atual
  Future<void> carregarPermissoesUsuario(String negocioId, String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _userPermissions = await _permissionsService.listarPermissoesUsuario(negocioId, userId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Carrega todos os roles do negócio
  Future<void> carregarRoles(String negocioId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _negocioRoles = await _permissionsService.listarRoles(negocioId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ============================================================================
  // VERIFICAÇÕES DE PERMISSÃO
  // ============================================================================

  /// Verifica se usuário tem permissão específica
  bool temPermissao(String permissionId) {
    return _userPermissions.any((p) => p.id == permissionId);
  }

  /// Verifica se usuário tem alguma das permissões
  bool temAlgumaPermissao(List<String> permissionIds) {
    return permissionIds.any((id) => temPermissao(id));
  }

  /// Verifica se usuário tem todas as permissões
  bool temTodasPermissoes(List<String> permissionIds) {
    return permissionIds.every((id) => temPermissao(id));
  }

  /// Verifica se usuário pode gerenciar permissões (admin)
  bool podeGerenciarPermissoes() {
    return temPermissao('settings.manage_permissions');
  }

  /// Verifica se usuário pode criar pacientes
  bool podecriarPacientes() {
    return temPermissao('patients.create');
  }

  /// Verifica se usuário pode ver pacientes
  bool podeVerPacientes() {
    return temPermissao('patients.read');
  }

  /// Verifica se usuário pode editar pacientes
  bool podeEditarPacientes() {
    return temPermissao('patients.update');
  }

  /// Verifica se usuário pode excluir pacientes
  bool podeExcluirPacientes() {
    return temPermissao('patients.delete');
  }

  /// Verifica se usuário pode criar consultas
  bool podeCriarConsultas() {
    return temPermissao('consultations.create');
  }

  /// Verifica se usuário pode criar exames
  bool podeCriarExames() {
    return temPermissao('exams.create');
  }

  /// Verifica se usuário pode criar medicações
  bool podeCriarMedicacoes() {
    return temPermissao('medications.create');
  }

  /// Verifica se usuário pode gerenciar equipe
  bool podeGerenciarEquipe() {
    return temAlgumaPermissao([
      'team.invite',
      'team.update_role',
      'team.update_status',
    ]);
  }

  // ============================================================================
  // GESTÃO DE ROLES
  // ============================================================================

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
      _isLoading = true;
      _error = null;
      notifyListeners();

      final novoRole = await _permissionsService.criarRole(
        negocioId,
        tipo: tipo,
        nivelHierarquico: nivelHierarquico,
        nomeCustomizado: nomeCustomizado,
        descricaoCustomizada: descricaoCustomizada,
        cor: cor,
        icone: icone,
        permissions: permissions,
      );

      // Atualizar lista de roles
      await carregarRoles(negocioId);

      _isLoading = false;
      notifyListeners();

      return novoRole;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
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
      _isLoading = true;
      _error = null;
      notifyListeners();

      final roleAtualizado = await _permissionsService.atualizarRole(
        negocioId,
        roleId,
        nomeCustomizado: nomeCustomizado,
        descricaoCustomizada: descricaoCustomizada,
        cor: cor,
        icone: icone,
        permissions: permissions,
        isActive: isActive,
      );

      // Atualizar lista de roles
      await carregarRoles(negocioId);

      _isLoading = false;
      notifyListeners();

      return roleAtualizado;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Exclui role
  Future<void> excluirRole(String negocioId, String roleId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _permissionsService.excluirRole(negocioId, roleId);

      // Atualizar lista de roles
      await carregarRoles(negocioId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  /// Limpa estado
  void limpar() {
    _userPermissions = [];
    _allPermissions = [];
    _permissionsByCategory = {};
    _negocioRoles = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Busca role por ID
  Role? buscarRolePorId(String roleId) {
    try {
      return _negocioRoles.firstWhere((r) => r.id == roleId);
    } catch (e) {
      return null;
    }
  }

  /// Busca permissão por ID
  Permission? buscarPermissaoPorId(String permissionId) {
    try {
      return _allPermissions.firstWhere((p) => p.id == permissionId);
    } catch (e) {
      return null;
    }
  }

  /// Conta quantas permissões o usuário tem
  int get totalPermissoesUsuario => _userPermissions.length;

  /// Verifica se está carregando
  bool get estaCarregando => _isLoading;

  /// Verifica se tem erro
  bool get temErro => _error != null;
}
