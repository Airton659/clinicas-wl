import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/permissions_provider.dart';

/// Widget que controla visibilidade baseado em permissões
///
/// Uso:
/// ```dart
/// PermissionGuard(
///   permission: 'patients.create',
///   child: ElevatedButton(
///     onPressed: () => criarPaciente(),
///     child: Text('Novo Paciente'),
///   ),
/// )
/// ```
class PermissionGuard extends StatelessWidget {
  /// Permissão necessária (ex: 'patients.create')
  final String? permission;

  /// Lista de permissões (usuário precisa ter ao menos uma)
  final List<String>? anyOf;

  /// Lista de permissões (usuário precisa ter todas)
  final List<String>? allOf;

  /// Widget filho a ser exibido se tiver permissão
  final Widget child;

  /// Widget a ser exibido se NÃO tiver permissão (opcional)
  final Widget? fallback;

  /// Se true, mostra widget desabilitado ao invés de esconder
  final bool showDisabled;

  const PermissionGuard({
    Key? key,
    this.permission,
    this.anyOf,
    this.allOf,
    required this.child,
    this.fallback,
    this.showDisabled = false,
  })  : assert(
          permission != null || anyOf != null || allOf != null,
          'Deve fornecer ao menos uma: permission, anyOf ou allOf',
        ),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final permissionsProvider = Provider.of<PermissionsProvider>(context);

    bool hasPermission = _checkPermission(permissionsProvider);

    // Se tem permissão, mostra o child normalmente
    if (hasPermission) {
      return child;
    }

    // Se NÃO tem permissão...

    // Se deve mostrar desabilitado
    if (showDisabled) {
      return Opacity(
        opacity: 0.5,
        child: IgnorePointer(
          child: child,
        ),
      );
    }

    // Se tem fallback, mostra fallback
    if (fallback != null) {
      return fallback!;
    }

    // Senão, não mostra nada
    return const SizedBox.shrink();
  }

  bool _checkPermission(PermissionsProvider provider) {
    // Verificar permissão única
    if (permission != null) {
      return provider.temPermissao(permission!);
    }

    // Verificar "qualquer uma de"
    if (anyOf != null) {
      return provider.temAlgumaPermissao(anyOf!);
    }

    // Verificar "todas de"
    if (allOf != null) {
      return provider.temTodasPermissoes(allOf!);
    }

    return false;
  }
}

/// Widget que mostra mensagem de acesso negado
class PermissionDenied extends StatelessWidget {
  final String? message;
  final IconData icon;

  const PermissionDenied({
    Key? key,
    this.message,
    this.icon = Icons.lock,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message ?? 'Você não tem permissão para acessar este recurso',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Mixin para facilitar verificações de permissão em widgets
mixin PermissionMixin {
  /// Verifica se usuário tem permissão
  bool hasPermission(BuildContext context, String permission) {
    final provider = Provider.of<PermissionsProvider>(context, listen: false);
    return provider.temPermissao(permission);
  }

  /// Verifica se usuário tem alguma das permissões
  bool hasAnyPermission(BuildContext context, List<String> permissions) {
    final provider = Provider.of<PermissionsProvider>(context, listen: false);
    return provider.temAlgumaPermissao(permissions);
  }

  /// Verifica se usuário tem todas as permissões
  bool hasAllPermissions(BuildContext context, List<String> permissions) {
    final provider = Provider.of<PermissionsProvider>(context, listen: false);
    return provider.temTodasPermissoes(permissions);
  }

  /// Mostra snackbar de permissão negada
  void showPermissionDenied(BuildContext context, {String? message}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message ?? 'Você não tem permissão para esta ação',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }
}
