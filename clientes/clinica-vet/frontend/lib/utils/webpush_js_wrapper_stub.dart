// lib/utils/webpush_js_wrapper_stub.dart
// Stub para mobile - Web Push só funciona na web

class WebPushJSWrapper {
  static Future<Map<String, dynamic>?> subscribe(String vapidPublicKey) async {
    return null;
  }

  static Future<Map<String, dynamic>?> getExistingSubscription() async {
    return null;
  }

  static Future<bool> unsubscribe() async {
    return false;
  }
}
