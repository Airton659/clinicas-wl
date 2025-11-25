// lib/utils/safari_webpush_wrapper.dart

import 'package:flutter/foundation.dart';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Wrapper Dart para chamar as funções JavaScript do Safari Web Push
/// Comunica-se com o arquivo safari-webpush.js carregado no index.html
@JS('SafariWebPush')
external JSObject? get _safariWebPush;

class SafariWebPushWrapper {
  /// Verifica se o SafariWebPush está disponível
  static bool get _isAvailable {
    if (!kIsWeb) return false;
    return _safariWebPush != null;
  }

  /// Verifica se o browser suporta Web Push
  static bool isSupported() {
    if (!_isAvailable) return false;

    try {
      final fn = _safariWebPush!.getProperty('isSupported'.toJS) as JSFunction;
      final result = fn.callAsFunction(_safariWebPush);
      return (result as JSBoolean).toDart;
    } catch (e) {
      debugPrint('❌ Erro ao verificar suporte a Web Push: $e');
      return false;
    }
  }

  /// Verifica se é Safari
  static bool isSafari() {
    if (!_isAvailable) return false;

    try {
      final fn = _safariWebPush!.getProperty('isSafari'.toJS) as JSFunction;
      final result = fn.callAsFunction(_safariWebPush);
      return (result as JSBoolean).toDart;
    } catch (e) {
      debugPrint('❌ Erro ao verificar se é Safari: $e');
      return false;
    }
  }

  /// Obtém o status da permissão de notificação
  /// Retorna: 'default', 'granted', 'denied', ou 'not-supported'
  static String getPermissionStatus() {
    if (!_isAvailable) return 'not-supported';

    try {
      final fn = _safariWebPush!.getProperty('getPermissionStatus'.toJS) as JSFunction;
      final result = fn.callAsFunction(_safariWebPush);
      return (result as JSString).toDart;
    } catch (e) {
      debugPrint('❌ Erro ao obter status de permissão: $e');
      return 'not-supported';
    }
  }

  /// Solicita permissão de notificação
  /// Retorna: 'granted', 'denied', ou 'default'
  static Future<String> requestPermission() async {
    if (!_isAvailable) return 'not-supported';

    try {
      final fn = _safariWebPush!.getProperty('requestPermission'.toJS) as JSFunction;
      final promise = fn.callAsFunction(_safariWebPush) as JSPromise;
      final result = await promise.toDart;
      return (result as JSString).toDart;
    } catch (e) {
      debugPrint('❌ Erro ao solicitar permissão: $e');
      return 'denied';
    }
  }

  /// Inicializa Safari Web Push (fluxo completo)
  /// Retorna um Map com:
  /// - success: bool
  /// - token: String? (endpoint APNs)
  /// - error: String? (se houver erro)
  static Future<Map<String, dynamic>> initialize() async {
    if (!kIsWeb) {
      return {'success': false, 'error': 'Not running on web'};
    }

    if (!_isAvailable) {
      return {
        'success': false,
        'error': 'SafariWebPush não está disponível. Verifique se safari-webpush.js está carregado.'
      };
    }

    try {
      debugPrint('🍎 Inicializando Safari Web Push...');

      final fn = _safariWebPush!.getProperty('initialize'.toJS) as JSFunction;
      final promise = fn.callAsFunction(_safariWebPush) as JSPromise;
      final jsResult = await promise.toDart;

      // Converte o resultado JavaScript para Map Dart
      final result = _jsObjectToMap(jsResult as JSObject);

      if (result['success'] == true) {
        debugPrint('✅ Safari Web Push inicializado com sucesso!');
        final token = result['token']?.toString() ?? '';
        if (token.length > 50) {
          debugPrint('   Token: ${token.substring(0, 50)}...');
        } else {
          debugPrint('   Token: $token');
        }
      } else {
        debugPrint('❌ Erro ao inicializar Safari Web Push: ${result['error']}');
      }

      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao inicializar Safari Web Push: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Verifica se já existe subscription ativa
  static Future<Map<String, dynamic>> checkExistingSubscription() async {
    if (!_isAvailable) {
      return {'hasSubscription': false};
    }

    try {
      final fn = _safariWebPush!.getProperty('checkExisting'.toJS) as JSFunction;
      final promise = fn.callAsFunction(_safariWebPush) as JSPromise;
      final jsResult = await promise.toDart;

      return _jsObjectToMap(jsResult as JSObject);
    } catch (e) {
      debugPrint('❌ Erro ao verificar subscription existente: $e');
      return {'hasSubscription': false, 'error': e.toString()};
    }
  }

  /// Remove subscription de Web Push
  static Future<bool> unsubscribe() async {
    if (!_isAvailable) return false;

    try {
      final fn = _safariWebPush!.getProperty('unsubscribe'.toJS) as JSFunction;
      final promise = fn.callAsFunction(_safariWebPush) as JSPromise;
      final result = await promise.toDart;

      return (result as JSBoolean).toDart;
    } catch (e) {
      debugPrint('❌ Erro ao remover subscription: $e');
      return false;
    }
  }

  /// Converte um objeto JavaScript para Map Dart
  static Map<String, dynamic> _jsObjectToMap(JSObject jsObject) {
    final Map<String, dynamic> result = {};

    try {
      // success
      if (jsObject.has('success')) {
        final success = jsObject.getProperty('success'.toJS);
        result['success'] = (success as JSBoolean?)?.toDart ?? false;
      }

      // token
      if (jsObject.has('token')) {
        final token = jsObject.getProperty('token'.toJS);
        if (token != null && !(token.isNull || token.isUndefined)) {
          result['token'] = (token as JSString).toDart;
        }
      }

      // endpoint
      if (jsObject.has('endpoint')) {
        final endpoint = jsObject.getProperty('endpoint'.toJS);
        if (endpoint != null && !(endpoint.isNull || endpoint.isUndefined)) {
          result['endpoint'] = (endpoint as JSString).toDart;
        }
      }

      // error
      if (jsObject.has('error')) {
        final error = jsObject.getProperty('error'.toJS);
        if (error != null && !(error.isNull || error.isUndefined)) {
          result['error'] = (error as JSString).toDart;
        }
      }

      // hasSubscription
      if (jsObject.has('hasSubscription')) {
        final hasSubscription = jsObject.getProperty('hasSubscription'.toJS);
        result['hasSubscription'] = (hasSubscription as JSBoolean?)?.toDart ?? false;
      }

      return result;
    } catch (e) {
      debugPrint('❌ Erro ao converter JS object para Map: $e');
      return result;
    }
  }

  /// Loga informações de debug do Safari Web Push
  static void logDebugInfo() {
    debugPrint('//======================================================//');
    debugPrint('// 🍎 SAFARI WEB PUSH DEBUG INFO');
    debugPrint('//======================================================//');
    debugPrint('   [is_available]: $_isAvailable');
    debugPrint('   [is_supported]: ${isSupported()}');
    debugPrint('   [is_safari]: ${isSafari()}');
    debugPrint('   [permission_status]: ${getPermissionStatus()}');
    debugPrint('//======================================================//');
  }
}

extension on JSObject {
  bool has(String property) {
    return hasProperty(property.toJS).toDart;
  }
}
