import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:analicegrubert/firebase_options.dart';
import 'package:analicegrubert/core/theme/app_theme.dart';
import 'package:analicegrubert/services/auth_service.dart';
import 'package:analicegrubert/services/notification_service.dart';
import 'package:analicegrubert/providers/notification_provider.dart';
import 'package:analicegrubert/api/api_service.dart';
import 'package:analicegrubert/services/cache_manager.dart';
import 'package:analicegrubert/widgets/url_router_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase com try/catch para lidar com problemas de emulador Android
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Configurar handler de mensagens em background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  } catch (e) {
    debugPrint('❌ Erro ao inicializar Firebase: $e');
  }

  // Inicializa o CacheManager e faz limpeza inicial
  final cacheManager = CacheManager.instance;
  await cacheManager.cleanupExpired();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
        ChangeNotifierProvider<NotificationService>(
          create: (_) => NotificationService(),
        ),
        ProxyProvider<AuthService, ApiService>(
          update: (context, authService, previous) =>
              ApiService(authService: authService),
        ),
        ChangeNotifierProxyProvider2<AuthService, ApiService, NotificationProvider>(
          create: (context) => NotificationProvider(
            apiService: ApiService(authService: AuthService()),
            authService: AuthService(),
            notificationService: context.read<NotificationService>(),
          ),
          update: (context, authService, apiService, previous) =>
              NotificationProvider(
                apiService: apiService,
                authService: authService,
                notificationService: context.read<NotificationService>(),
              ),
        ),
        ProxyProvider<AuthService, void>(
          update: (context, authService, previous) {
            // Inicializar NotificationService quando AuthService estiver pronto
            if (authService.currentUser != null) {
              final notificationService = context.read<NotificationService>();
              debugPrint('🚀 INICIALIZANDO NotificationService para user: ${authService.currentUser?.email}');
              notificationService.initialize(authService);
              debugPrint('✅ NotificationService inicializado');
            }
          },
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Gestão Clínica',
        theme: AppTheme.lightTheme,

        // ==== LOCALIZAÇÃO (necessário para DatePickerDialog) ====
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [
          Locale('pt', 'BR'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // =========================================================

        home: const UrlRouterWrapper(),
      ),
    );
  }
}
