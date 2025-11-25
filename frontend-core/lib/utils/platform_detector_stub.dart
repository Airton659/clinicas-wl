// lib/utils/platform_detector_stub.dart
// STUB para plataformas mobile (Android/iOS)
// Este arquivo é usado quando NÃO é web

import 'package:flutter/foundation.dart';

class PlatformDetector {
  static bool get isSafari => false;
  static bool get isIOS => false;
  static bool get isMacOS => false;
  static bool get isSafariIOS => false;
  static bool get isSafariMacOS => false;
  static bool get isSafariCompatibleWithWebPush => false;
  static bool get shouldUseAPNs => false;
  static bool get shouldUseFCM => true; // Mobile sempre usa FCM

  static Map<String, dynamic> get browserInfo {
    return {
      'platform': 'mobile',
      'is_web': false,
      'should_use_fcm': true,
      'should_use_apns': false,
    };
  }

  static void logBrowserInfo() {
    debugPrint('//======================================================//');
    debugPrint('// 📱 PLATFORM: MOBILE (Android/iOS)');
    debugPrint('//======================================================//');
    debugPrint('   [platform]: mobile');
    debugPrint('   [should_use_fcm]: true');
    debugPrint('//======================================================//');
  }
}
