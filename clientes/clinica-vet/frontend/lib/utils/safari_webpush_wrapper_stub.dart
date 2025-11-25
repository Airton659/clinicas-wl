// lib/utils/safari_webpush_wrapper_stub.dart
// STUB para plataformas mobile (Android/iOS)
// Este arquivo é usado quando NÃO é web

import 'package:flutter/foundation.dart';

class SafariWebPushWrapper {
  static bool isSupported() => false;
  static bool isSafari() => false;
  static String getPermissionStatus() => 'not-supported';

  static Future<Map<String, dynamic>> initialize() async {
    return {
      'success': false,
      'error': 'Web Push não disponível em plataformas mobile',
    };
  }

  static Future<Map<String, dynamic>> checkExistingSubscription() async {
    return {
      'hasSubscription': false,
      'token': null,
    };
  }

  static void logDebugInfo() {
    debugPrint('🍎 SafariWebPush: Não disponível em mobile');
  }
}
