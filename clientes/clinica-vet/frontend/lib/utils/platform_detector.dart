// lib/utils/platform_detector.dart

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Classe para detectar plataforma e browser específico
/// Usado para diferenciar Safari de outros browsers e aplicar lógica específica
class PlatformDetector {
  /// Detecta se está rodando no Safari (macOS ou iOS)
  /// Safari no macOS e iOS tem comportamentos diferentes de Chrome/Edge
  static bool get isSafari {
    if (!kIsWeb) return false;

    final userAgent = web.window.navigator.userAgent;
    // Safari contém "Safari" mas NÃO contém "Chrome" no user agent
    // Chrome/Edge também têm "Safari" no UA, mas incluem "Chrome"
    // IMPORTANTE: Chrome no iOS usa "CriOS" e não "Chrome"
    final containsSafari = userAgent.contains('Safari');
    final notChrome = !userAgent.contains('Chrome') &&
                      !userAgent.contains('Chromium') &&
                      !userAgent.contains('CriOS');  // Chrome no iOS
    final notEdge = !userAgent.contains('Edg') && !userAgent.contains('EdgiOS');  // Edge no iOS
    final notFirefox = !userAgent.contains('FxiOS');  // Firefox no iOS

    return containsSafari && notChrome && notEdge && notFirefox;
  }

  /// Detecta se está rodando no iOS (iPhone/iPad)
  static bool get isIOS {
    if (!kIsWeb) return false;

    final userAgent = web.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('iphone') ||
           userAgent.contains('ipad') ||
           userAgent.contains('ipod');
  }

  /// Detecta se está rodando no macOS
  static bool get isMacOS {
    if (!kIsWeb) return false;

    final userAgent = web.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('mac os x') || userAgent.contains('macintosh');
  }

  /// Detecta se é Safari no iOS (Safari Mobile)
  static bool get isSafariIOS {
    return isSafari && isIOS;
  }

  /// Detecta se é Safari no macOS (Safari Desktop)
  static bool get isSafariMacOS {
    return isSafari && isMacOS;
  }

  /// Verifica se o Safari suporta Web Push (Safari 16.4+)
  /// Web Push só funciona a partir do Safari 16.4 (lançado em março 2023)
  static bool get isSafariCompatibleWithWebPush {
    if (!isSafari) return false;

    try {
      final userAgent = web.window.navigator.userAgent;

      // Extrai a versão do Safari do user agent
      // Exemplo: "Version/16.4 Safari/605.1.15"
      final versionMatch = RegExp(r'Version/(\d+)\.(\d+)').firstMatch(userAgent);

      if (versionMatch != null) {
        final majorVersion = int.tryParse(versionMatch.group(1) ?? '0') ?? 0;
        final minorVersion = int.tryParse(versionMatch.group(2) ?? '0') ?? 0;

        // Web Push requer Safari 16.4+
        if (majorVersion > 16) return true;
        if (majorVersion == 16 && minorVersion >= 4) return true;

        return false;
      }

      // Se não conseguir detectar a versão, assume que é compatível
      // (melhor tentar do que bloquear)
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao detectar versão do Safari: $e');
      return true; // Assume compatibilidade em caso de erro
    }
  }

  /// Detecta se deve usar APNs (Web Push nativo do Safari)
  /// Retorna true se for Safari compatível com Web Push
  static bool get shouldUseAPNs {
    return isSafari && isSafariCompatibleWithWebPush;
  }

  /// Detecta se deve usar Firebase Cloud Messaging (FCM)
  /// Retorna true para Chrome, Edge, Opera, Firefox, etc
  static bool get shouldUseFCM {
    return !shouldUseAPNs;
  }

  /// Retorna informações detalhadas do browser para debug
  static Map<String, dynamic> get browserInfo {
    if (!kIsWeb) {
      return {
        'platform': 'native',
        'is_web': false,
      };
    }

    return {
      'platform': 'web',
      'is_web': true,
      'user_agent': web.window.navigator.userAgent,
      'is_safari': isSafari,
      'is_ios': isIOS,
      'is_macos': isMacOS,
      'is_safari_ios': isSafariIOS,
      'is_safari_macos': isSafariMacOS,
      'safari_compatible_with_webpush': isSafariCompatibleWithWebPush,
      'should_use_apns': shouldUseAPNs,
      'should_use_fcm': shouldUseFCM,
    };
  }

  /// Loga informações do browser no console para debug
  static void logBrowserInfo() {
    final info = browserInfo;
    debugPrint('//======================================================//');
    debugPrint('// 🌐 BROWSER DETECTION INFO');
    debugPrint('//======================================================//');
    info.forEach((key, value) {
      debugPrint('   [$key]: $value');
    });
    debugPrint('//======================================================//');
  }
}
