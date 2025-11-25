// lib/firebase_options.dart (VERSÃO FINAL E CORRETA)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      // Adicione outras plataformas se necessário
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Configuração correta para o seu app Android "analicegrubert"
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAosIiTVqVuzdfqRcwV-wDmuA36ViE-Emw',
    appId: '1:862082955632:android:bc9d434fe67bcf309cb7b5',
    messagingSenderId: '862082955632',
    projectId: 'teste-notificacao-barbearia',
    storageBucket: 'teste-notificacao-barbearia.firebasestorage.app',
  );

  // Configuração para o seu app iOS "analicegrubert"
  // NOTA: O "appId" do iOS pode precisar ser atualizado do seu console Firebase se este não funcionar.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCX2odnSInjrKb5HdOLA5rGoXrv58e7dMQ',
    appId: '1:862082955632:ios:6d037034a46b76349cb7b5', // Pode precisar ser ajustado
    messagingSenderId: '862082955632',
    projectId: 'teste-notificacao-barbearia',
    storageBucket: 'teste-notificacao-barbearia.firebasestorage.app',
    iosBundleId: 'com.example.analicegrubert',
  );

  // Configuração para Web
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC073ifaNVWcVwFi4e3agdl-yX7aaKsMwk',
    appId: '1:862082955632:web:ae8823c881d702d79cb7b5',
    messagingSenderId: '862082955632',
    projectId: 'teste-notificacao-barbearia',
    storageBucket: 'teste-notificacao-barbearia.firebasestorage.app',
    authDomain: 'teste-notificacao-barbearia.firebaseapp.com',
  );
}