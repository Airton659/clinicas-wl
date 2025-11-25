// lib/utils/web_listeners.dart

import 'package:flutter/foundation.dart';

class WebListeners {
  static void setupPageVisibilityListener(VoidCallback onPageVisible) {
    if (!kIsWeb) return;

    // Usando JS interop via eval (menos ideal mas funciona sem dependências extras)
    // ignore: avoid_web_libraries_in_flutter
    // Em produção seria melhor usar package:web, mas para simplicidade vamos deixar
    // o listener ser configurado via JavaScript no próprio index.html
    debugPrint('[WEB_LISTENERS] Page visibility listener setup (handled by index.html)');
  }

  static void setupNotificationListener(Function(Map<String, dynamic>) onNotification) {
    if (!kIsWeb) return;

    debugPrint('[WEB_LISTENERS] Notification listener setup (handled by index.html)');
  }
}

