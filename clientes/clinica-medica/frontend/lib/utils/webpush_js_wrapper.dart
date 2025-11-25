// lib/utils/webpush_js_wrapper.dart
// Ponte Dart <-> JavaScript para Web Push VAPID

import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('WebPushManager.subscribe')
external JSPromise _jsSubscribe(JSString vapidPublicKey);

@JS('WebPushManager.getExistingSubscription')
external JSPromise _jsGetExistingSubscription();

@JS('WebPushManager.unsubscribe')
external JSPromise _jsUnsubscribe();

// Extensão para acessar propriedades de objetos JavaScript
extension on JSObject {
  external JSAny? operator [](String property);
}

class WebPushJSWrapper {
  /// Cria uma subscription Web Push usando VAPID
  static Future<Map<String, dynamic>?> subscribe(String vapidPublicKey) async {
    try {
      if (!kIsWeb) return null;

      debugPrint('[VAPID-DART] Chamando JavaScript subscribe...');

      final promise = _jsSubscribe(vapidPublicKey.toJS);
      final result = await promise.toDart;

      if (result == null || result.isNull) {
        debugPrint('[VAPID-DART] JavaScript retornou null');
        return null;
      }

      // Converte JSObject para Map
      final jsObject = result as JSObject;
      final subscription = _jsObjectToMap(jsObject);

      debugPrint('[VAPID-DART] Subscription obtida: ${subscription.keys}');
      return subscription;

    } catch (e, stackTrace) {
      debugPrint('[VAPID-DART] Erro ao criar subscription: $e');
      debugPrint('[VAPID-DART] Stack: $stackTrace');
      return null;
    }
  }

  /// Verifica se já existe subscription
  static Future<Map<String, dynamic>?> getExistingSubscription() async {
    try {
      if (!kIsWeb) return null;

      final promise = _jsGetExistingSubscription();
      final result = await promise.toDart;

      if (result == null || result.isNull) {
        return null;
      }

      final jsObject = result as JSObject;
      return _jsObjectToMap(jsObject);

    } catch (e) {
      debugPrint('[VAPID-DART] Erro ao verificar subscription: $e');
      return null;
    }
  }

  /// Remove subscription
  static Future<bool> unsubscribe() async {
    try {
      if (!kIsWeb) return false;

      final promise = _jsUnsubscribe();
      final result = await promise.toDart;

      return (result as JSBoolean?)?.toDart ?? false;

    } catch (e) {
      debugPrint('[VAPID-DART] Erro ao remover subscription: $e');
      return false;
    }
  }

  /// Converte JSObject para Map Dart
  static Map<String, dynamic> _jsObjectToMap(JSObject obj) {
    final map = <String, dynamic>{};

    try {
      // Acessa propriedades do objeto JavaScript usando o operador []
      final endpoint = obj['endpoint'];
      final keys = obj['keys'];

      map['endpoint'] = (endpoint as JSString?)?.toDart ?? '';

      if (keys != null && !keys.isNull) {
        final keysObj = keys as JSObject;
        final p256dh = keysObj['p256dh'];
        final auth = keysObj['auth'];

        map['keys'] = {
          'p256dh': (p256dh as JSString?)?.toDart ?? '',
          'auth': (auth as JSString?)?.toDart ?? '',
        };
      }

    } catch (e) {
      debugPrint('[VAPID-DART] Erro ao converter JSObject: $e');
    }

    return map;
  }
}
