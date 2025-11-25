import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../screens/reset_password_page.dart';
import 'auth_wrapper.dart';

class UrlRouterWrapper extends StatelessWidget {
  const UrlRouterWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Verifica se estamos na web e se a URL contém parâmetros de ação do Firebase
    if (kIsWeb) {
      final uri = Uri.base;
      final fragment = uri.fragment;

      // Verifica se é uma rota de reset de senha
      if (fragment.contains('/reset-password')) {
        // Extrai o código de ação da URL
        final queryParams = Uri.parse('?$fragment').queryParameters;
        final oobCode = queryParams['oobCode'];

        if (oobCode != null) {
          return ResetPasswordPage(oobCode: oobCode);
        }
      }

      // Também verifica se o código vem diretamente nos query parameters (formato alternativo do Firebase)
      if (uri.queryParameters.containsKey('oobCode')) {
        final mode = uri.queryParameters['mode'];
        final oobCode = uri.queryParameters['oobCode'];

        if (mode == 'resetPassword' && oobCode != null) {
          return ResetPasswordPage(oobCode: oobCode);
        }
      }
    }

    // Se não for uma ação especial, mostra o AuthWrapper normal
    return const AuthWrapper();
  }
}
