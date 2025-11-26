// lib/services/notification_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:analicegrubert/models/notification_types.dart';
import 'package:analicegrubert/api/api_service.dart';
import 'package:analicegrubert/config/app_config.dart';
import 'package:analicegrubert/services/auth_service.dart';
import 'package:analicegrubert/screens/patient_details_page.dart';
import 'package:analicegrubert/screens/client_dashboard.dart';
import 'package:analicegrubert/services/cache_manager.dart';
import 'package:provider/provider.dart';
// NOVOS IMPORTS PARA SAFARI/APNS (condicionais para web/mobile)
import 'package:analicegrubert/utils/platform_detector.dart'
    if (dart.library.io) 'package:analicegrubert/utils/platform_detector_stub.dart';
import 'package:analicegrubert/utils/safari_webpush_wrapper.dart'
    if (dart.library.io) 'package:analicegrubert/utils/safari_webpush_wrapper_stub.dart';
// Import condicional para Web Push VAPID
import 'dart:html' as html if (dart.library.io) '';
import 'package:analicegrubert/utils/webpush_js_wrapper.dart'
    if (dart.library.io) 'package:analicegrubert/utils/webpush_js_wrapper_stub.dart';

class NotificationService with ChangeNotifier {
  // ... (todo o início do seu arquivo permanece igual) ...
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final List<NotificationData> _notifications = [];
  String? _fcmToken;
  ApiService? _apiService;
  AuthService? _authService;
  dynamic _notificationProvider;
  BuildContext? _navigationContext;
  VoidCallback? _homeReloadCallback;

  // Canal nativo para notificações
  static const MethodChannel _notificationChannel = MethodChannel('analice_grubert_notifications');

  // StreamController para notificar as telas sobre novas notificações
  final _notificationStreamController = StreamController<NotificationType?>.broadcast();
  Stream<NotificationType?> get notificationStream => _notificationStreamController.stream;

  // Cache de notificações recentes para deduplicação (evita duplicatas em foreground)
  final Map<String, DateTime> _recentNotifications = {};

  List<NotificationData> get notifications => List.unmodifiable(_notifications);
  String? get fcmToken => _fcmToken;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;


  void setNotificationProvider(dynamic provider) {
    _notificationProvider = provider;
  }

  void setNavigationContext(BuildContext context) {
    _navigationContext = context;
  }

  void setHomeReloadCallback(VoidCallback? callback) {
    _homeReloadCallback = callback;
  }

  void initialize(AuthService authService) {
    debugPrint('🔥 NOTIFICATION_DEBUG: NotificationService.initialize chamado');
    _authService = authService;
    _apiService = ApiService(authService: authService);
    _initializeFirebaseMessaging();
    _isInitialized = true;

    // ✨ LINHA ADICIONADA ✨
    // Força a verificação e o envio do token mais recente para o backend.
    // Isso ajuda a prevenir o erro "Requested entity was not found".
    forceRefreshToken();
  }

  Future<void> _testNativeNotification() async {
    try {
      debugPrint('🧪 NOTIFICATION_DEBUG: Testando notificação nativa...');

      final result = await _notificationChannel.invokeMethod('showNotification', {
        'title': 'TESTE FUNCIONOU! 🎉',
        'body': 'As notificações nativas estão funcionando perfeitamente!',
        'id': 999,
      });
      debugPrint('🧪 NOTIFICATION_DEBUG: ✅ Notificação nativa enviada com sucesso!');
    } catch (e) {
      debugPrint('🧪 NOTIFICATION_DEBUG: ❌ Erro na notificação nativa: $e');
    }
  }

  Future<void> _initializeFirebaseMessaging() async {
    try {
      // DEBUG: Log para identificar qual caminho está sendo tomado
      debugPrint('🌐 NOTIFICATION_DEBUG: kIsWeb = $kIsWeb');
      if (kIsWeb) {
        debugPrint('🌐 NOTIFICATION_DEBUG: shouldUseAPNs = ${PlatformDetector.shouldUseAPNs}');
        debugPrint('🌐 NOTIFICATION_DEBUG: shouldUseFCM = ${PlatformDetector.shouldUseFCM}');
        PlatformDetector.logBrowserInfo();
      }

      // NOVO: Verificar se é Safari e deve usar APNs
      if (kIsWeb && PlatformDetector.shouldUseAPNs) {
        debugPrint('🍎 NOTIFICATION_DEBUG: Safari detectado - usando APNs Web Push');
        await _initializeApnsWebPush();
        return;
      }

      // Código original do FCM continua aqui para outros browsers/plataformas
      debugPrint('🔥 NOTIFICATION_DEBUG: Inicializando Firebase Messaging (FCM)');

      // Solicitar permissões
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('🔥 NOTIFICATION_DEBUG: Status permissão Firebase: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('🔥 NOTIFICATION_DEBUG: ✅ Permissões de notificação concedidas');
      } else {
        debugPrint('🔥 NOTIFICATION_DEBUG: ❌ Permissões de notificação negadas');
        return;
      }

      // Obter token FCM
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        debugPrint('🔥 NOTIFICATION_DEBUG: 🔑 FCM Token obtido: ${_fcmToken!.substring(0, 20)}...');
      }

      // Enviar token para o backend
      if (_fcmToken != null) {
        await _sendTokenToBackend(_fcmToken!);
        debugPrint('🔥 NOTIFICATION_DEBUG: 📤 Token enviado para backend');
      }

      // Configurar handlers de mensagens
      _setupMessageHandlers();

      // Listener para mudanças de token
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔥 NOTIFICATION_DEBUG: 🔄 Token FCM atualizado');
        _fcmToken = newToken;
        _sendTokenToBackend(newToken);
      });

      debugPrint('🔥 NOTIFICATION_DEBUG: ✅ Firebase Messaging inicializado com sucesso');

    } catch (e) {
      debugPrint('🔥 NOTIFICATION_DEBUG: ❌ Erro ao inicializar Firebase Messaging: $e');

      // FALLBACK: Se FCM falhar na web, tenta APNs (pode ser Safari)
      if (kIsWeb) {
        debugPrint('🍎 NOTIFICATION_DEBUG: FCM falhou, tentando APNs como fallback...');
        await _initializeApnsWebPush();
      }
    }
  }

  /// Inicializa APNs Web Push para Safari
  Future<void> _initializeApnsWebPush() async {
    try {
      debugPrint('🍎 NOTIFICATION_DEBUG: Inicializando APNs Web Push...');
      SafariWebPushWrapper.logDebugInfo();

      // 1. Verificar se já existe subscription
      final existing = await SafariWebPushWrapper.checkExistingSubscription();

      if (existing['hasSubscription'] == true) {
        debugPrint('🍎 NOTIFICATION_DEBUG: ✅ Subscription APNs já existe');
        final token = existing['token'] as String?;
        if (token != null && token.isNotEmpty) {
          await _sendApnsTokenToBackend(token);
          debugPrint('🍎 NOTIFICATION_DEBUG: ✅ Token APNs existente enviado para backend');
        }
        return;
      }

      // 2. Inicializar novo
      debugPrint('🍎 NOTIFICATION_DEBUG: Criando nova subscription APNs...');
      final result = await SafariWebPushWrapper.initialize();

      if (result['success'] == true) {
        final apnsToken = result['token'] as String?;
        if (apnsToken != null && apnsToken.isNotEmpty) {
          final preview = apnsToken.length > 50 ? '${apnsToken.substring(0, 50)}...' : apnsToken;
          debugPrint('🍎 NOTIFICATION_DEBUG: ✅ Token APNs obtido: $preview');

          // 3. Enviar para backend
          await _sendApnsTokenToBackend(apnsToken);
          debugPrint('🍎 NOTIFICATION_DEBUG: ✅ Token APNs enviado para backend');
        } else {
          debugPrint('🍎 NOTIFICATION_DEBUG: ⚠️ Token APNs está vazio');
        }
      } else {
        final error = result['error'] ?? 'Erro desconhecido';
        debugPrint('🍎 NOTIFICATION_DEBUG: ❌ Falha ao inicializar APNs: $error');
      }

    } catch (e, stackTrace) {
      debugPrint('🍎 NOTIFICATION_DEBUG: ❌ Erro ao inicializar APNs Web Push: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Envia token APNs (Safari) para o backend
  Future<void> _sendApnsTokenToBackend(String token) async {
    if (token.isEmpty) {
      debugPrint('🍎 NOTIFICATION_DEBUG: ❌ Token APNs é vazio');
      return;
    }

    try {
      if (_apiService == null) {
        debugPrint('🍎 NOTIFICATION_DEBUG: ⚠️ ApiService não disponível ainda');
        return;
      }

      // Chama o método do ApiService para registrar token APNs
      await _apiService!.registerApnsToken(token);
      debugPrint('🍎 NOTIFICATION_DEBUG: ✅ Token APNs registrado no backend com sucesso');

    } catch (e) {
      debugPrint('🍎 NOTIFICATION_DEBUG: ❌ Erro ao enviar token APNs para backend: $e');
    }
  }

  void _setupMessageHandlers() {
    // Mensagem recebida quando app está em foreground REAL
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Só processa se o app realmente estava visível quando chegou
      if (kIsWeb) {
        // Na web, verifica se documento está visível
        if (html.document.visibilityState == 'visible') {
          debugPrint('   [FOREGROUND] App estava VISÍVEL quando notificação chegou');
          _handleMessage(message, 'FOREGROUND');
        } else {
          debugPrint('   [BACKGROUND] App estava OCULTO, ignorando (já foi processada pelo SW)');
        }
      } else {
        // Mobile sempre processa
        _handleMessage(message, 'FOREGROUND');
      }
    });

    // Mensagem clicada quando app está em background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessageTap(message);
    });

    // Verificar se app foi aberto por notificação
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleMessageTap(message);
      }
    });
  }

  Future<void> _handleMessage(RemoteMessage message, String origin) async {
    try {
      // ---- DEDUPLICAÇÃO: Verifica se já exibiu esta notificação recentemente ----
      final tipo = message.data['tipo'] ?? '';
      final consultaId = message.data['consulta_id'] ?? '';
      final pacienteId = message.data['paciente_id'] ?? '';
      final relatorioId = message.data['relatorio_id'] ?? '';
      final tarefaId = message.data['tarefa_id'] ?? '';
      final exameId = message.data['exame_id'] ?? '';

      // Gera chave única baseada no tipo + IDs relevantes
      final notificationKey = '$tipo-$consultaId-$pacienteId-$relatorioId-$tarefaId-$exameId';
      final now = DateTime.now();

      // Se já exibiu nos últimos 5 segundos, ignora (duplicata)
      if (_recentNotifications.containsKey(notificationKey)) {
        final lastShown = _recentNotifications[notificationKey]!;
        if (now.difference(lastShown).inSeconds < 5) {
          debugPrint('   [DEDUPLICAÇÃO] ⚠️ Notificação duplicada ignorada: $notificationKey');
          return;
        }
      }

      // Registra como exibida
      _recentNotifications[notificationKey] = now;

      // Limpa cache de notificações antigas (mais de 10 segundos)
      _recentNotifications.removeWhere((key, time) =>
        now.difference(time).inSeconds > 10
      );

      // ---- LOGS DETALHADOS E CORRIGIDOS ----
      debugPrint('//======================================================//');
      debugPrint('// 📲 NOVA NOTIFICAÇÃO RECEBIDA (ORIGEM: $origin)');
      debugPrint('//======================================================//');

      if (message.notification != null) {
        debugPrint('   [notification -> title]: "${message.notification?.title}"');
        debugPrint('   [notification -> body]:  "${message.notification?.body}"');
      } else {
        debugPrint('   [notification]: null');
      }

      if (message.data.isNotEmpty) {
        debugPrint('   [data -> payload]:');
        message.data.forEach((key, value) {
          debugPrint('     - $key: "$value"');
        });
      } else {
        debugPrint('   [data -> payload]: Vazio');
      }
      debugPrint('//======================================================//');
      // ---- FIM DOS LOGS ----

      final notification = NotificationData.fromMap({
        'title': message.notification?.title ?? message.data['title'],
        'body': message.notification?.body ?? message.data['body'],
        ...message.data,
      });

      // Transmite o tipo da notificação para quem estiver ouvindo
      debugPrint('   [STREAM] Transmitindo notificação do tipo [${notification.type}] para as telas...');
      _notificationStreamController.add(notification.type);

      _notifications.insert(0, notification);

      if (_notifications.length > 50) {
        _notifications.removeRange(50, _notifications.length);
      }

      notifyListeners();

      if (_notificationProvider != null) {
        try {
          debugPrint('   [PROVIDER] Notificando provider para atualizar contador...');
          _notificationProvider.onNewNotificationReceived();
          debugPrint('   [PROVIDER] ✅ Provider notificado com sucesso');
        } catch (e) {
          debugPrint('   [PROVIDER] ❌ Falha ao notificar provider: $e');
        }
      } else {
        debugPrint('   [PROVIDER] ⚠️ Provider não está inicializado!');
      }

      await _showNativeNotification(notification);

      if (notification.type == NotificationType.tarefaAtrasada ||
          notification.type == NotificationType.tarefaAtrasadaTecnico) {
        _triggerHomeReload();
      }

      // LÓGICA DE CACHE CORRIGIDA AQUI
      if (notification.type == NotificationType.planoAtualizado) {
        final pacienteId = notification.data['pacienteId'];
        if (pacienteId != null) {
          await CacheManager.instance.invalidatePatientCache(pacienteId);
        }
      }

    } catch (e) {
      debugPrint('   [ERRO CRÍTICO] Falha ao processar notificação: $e');
    }
  }

  // ... (todo o resto do seu arquivo permanece igual) ...
  Future<void> _showNativeNotification(NotificationData notification) async {
    try {
      // Verifica se está rodando na web
      if (kIsWeb) {
        debugPrint('   [WEB] Mostrando popup de notificação em foreground');
        // Mostra um snackbar/toast visual quando em foreground
        _showWebNotificationPopup(notification);
        return;
      }

      // Para mobile (Android/iOS), usa o canal nativo
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _notificationChannel.invokeMethod('showNotification', {
        'title': notification.title,
        'body': notification.body,
        'id': notificationId,
      });

    } catch (e) {
      debugPrint('   [ERRO] Falha ao chamar método nativo: $e');
    }
  }

  void _showWebNotificationPopup(NotificationData notification) {
    if (_navigationContext == null) return;

    try {
      final scaffoldMessenger = ScaffoldMessenger.of(_navigationContext!);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(notification.body),
            ],
          ),
          backgroundColor: const Color(0xFF0175C2),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint('[WEB] Erro ao mostrar popup: $e');
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    try {
      final notification = NotificationData.fromMap({
        'title': message.notification?.title ?? '',
        'body': message.notification?.body ?? '',
        ...message.data,
      });

      _navigateToScreen(notification);

    } catch (e) {
      debugPrint('❌ Erro ao processar tap da mensagem: $e');
    }
  }

  String? _getUserRole() {
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    final role = _authService?.currentUser?.roles?[negocioId];
    return role;
  }

  bool _isClient([BuildContext? context]) {
    String? userRole = _getUserRole();

    if (userRole == null && context != null) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        const negocioId = "rlAB6phw0EBsBFeDyOt6";
        userRole = authService.currentUser?.roles?[negocioId];
      } catch (e) {
        debugPrint('❌ Erro ao acessar AuthService via Provider: $e');
      }
    }

    final isClient = userRole == 'cliente' || userRole == 'paciente' || userRole == null;
    return isClient;
  }

  void _navigateToScreen(NotificationData notification) {
    debugPrint('🚀 Navegando para tela baseada na notificação: ${notification.type}');

    switch (notification.type) {
      case NotificationType.relatorioAvaliado:
        final data = RelatorioAvaliadoNotification.fromData(notification.data);
        break;

      case NotificationType.planoAtualizado:
        final data = PlanoAtualizadoNotification.fromData(notification.data);
        break;

      case NotificationType.associacaoProfissional:
        final data = AssociacaoProfissionalNotification.fromData(notification.data);
        break;

      // ❌ DESABILITADO
      // case NotificationType.checklistConcluido:
      //   final data = ChecklistConcluidoNotification.fromData(notification.data);
      //   break;

      case NotificationType.tarefaAtrasada:
        debugPrint('🔔 TAREFA_ATRASADA: Navegação desabilitada (apenas log)');
        final data = TarefaAtrasadaNotification.fromData(notification.data);
        debugPrint('   Paciente ID: ${data.pacienteId}');
        debugPrint('   Tarefa ID: ${data.tarefaId}');
        debugPrint('   Título: ${data.titulo}');
        debugPrint('   Vencimento: ${data.dataHoraLimite}');
        break;

      case NotificationType.tarefaAtrasadaTecnico:
        debugPrint('🔔 TAREFA_ATRASADA_TECNICO: Navegação desabilitada (apenas log)');
        final data = TarefaAtrasadaTecnicoNotification.fromData(notification.data);
        debugPrint('   Paciente ID: ${data.pacienteId}');
        debugPrint('   Tarefa ID: ${data.tarefaId}');
        break;

      case NotificationType.tarefaConcluida:
        final data = TarefaConcluidaNotification.fromData(notification.data);
        break;

      case NotificationType.lembreteExame:
        final data = LembreteExameNotification.fromData(notification.data);
        _navigateToExames(data.pacienteId, data.exameId);
        break;

      case NotificationType.exameCriado:
        final data = ExameCriadoNotification.fromData(notification.data);
        _navigateToExames(data.pacienteId, data.exameId);
        break;

      // ❌ DESABILITADO
      // case NotificationType.suporteAdicionado:
      //   final data = SuporteAdicionadoNotification.fromData(notification.data);
      //   _navigateToSuportePsicologico(data.pacienteId, data.suporteId);
      //   break;

      // ❌ DESABILITADO
      // case NotificationType.novoAgendamento:
      //   final data = NovoAgendamentoNotification.fromData(notification.data);
      //   break;

      // ❌ DESABILITADO
      // case NotificationType.agendamentoCancelado:
      //   final data = AgendamentoCanceladoNotification.fromData(notification.data);
      //   break;

      // ❌ DESABILITADO
      // case NotificationType.lembretePersonalizado:
      //   final data = LembretePersonalizadoNotification.fromData(notification.data);
      //   break;

      case NotificationType.novoRelatorioMedico:
        final data = NovoRelatorioMedicoNotification.fromData(notification.data);
        break;

      // ❌ DESABILITADO
      // case NotificationType.novoRegistroDiario:
      //   final data = NovoRegistroDiarioNotification.fromData(notification.data);
      //   break;
      
      default:
        debugPrint('🤷‍♂️ Tipo de notificação não tratado para navegação: ${notification.type}');
        break;
    }
  }

  void _navigateToExames(String pacienteId, String? exameId) {
    if (_navigationContext != null && _navigationContext!.mounted) {
      try {
        if (_isClient(_navigationContext)) {
          Navigator.of(_navigationContext!).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const ClientDashboard(),
            ),
            (route) => false,
          );
        } else {
          Navigator.of(_navigationContext!).push(
            MaterialPageRoute(
              builder: (context) => PatientDetailsPage(
                pacienteId: pacienteId,
                initialTabIndex: 1, 
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Erro ao navegar para exames: $e');
      }
    } else {
      debugPrint('❌ Context de navegação não disponível');
    }
  }

  void _navigateToSuportePsicologico(String pacienteId, String? suporteId) {
    if (_navigationContext != null && _navigationContext!.mounted) {
      try {
        if (_isClient(_navigationContext)) {
          Navigator.of(_navigationContext!).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const ClientDashboard(),
            ),
            (route) => false,
          );
        } else {
          Navigator.of(_navigationContext!).push(
            MaterialPageRoute(
              builder: (context) => PatientDetailsPage(
                pacienteId: pacienteId,
                initialTabIndex: 3, 
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Erro ao navegar para suporte psicológico: $e');
      }
    } else {
      debugPrint('❌ Context de navegação não disponível');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      debugPrint('🔥 SEND_TOKEN_DEBUG: Iniciando envio de token para backend...');
      debugPrint('🔥 SEND_TOKEN_DEBUG: Token: ${token.substring(0, 30)}...');

      if (_apiService == null) {
        debugPrint('❌ SEND_TOKEN_DEBUG: ApiService é null! Token não enviado.');
        return;
      }

      if (_authService?.currentUser == null) {
        debugPrint('❌ SEND_TOKEN_DEBUG: Usuário não autenticado! Token não enviado.');
        return;
      }

      debugPrint('🔥 SEND_TOKEN_DEBUG: Chamando apiService.updateFcmToken...');
      await _apiService!.updateFcmToken(token);
      debugPrint('✅ SEND_TOKEN_DEBUG: Token enviado com sucesso para o backend!');
      debugPrint('✅ SEND_TOKEN_DEBUG: Usuário ID: ${_authService?.currentUser?.id}');
    } catch (e) {
      debugPrint('❌ SEND_TOKEN_DEBUG: Erro ao enviar token para backend: $e');
      debugPrint('❌ SEND_TOKEN_DEBUG: Stack trace: ${StackTrace.current}');
    }
  }

  void markAsRead(int index) {
    if (index >= 0 && index < _notifications.length) {
      _notifications.removeAt(index);
      notifyListeners();
    }
  }

  void markAllAsRead() {
    _notifications.clear();
    notifyListeners();
  }

  int get unreadCount => _notifications.length;

  void _triggerHomeReload() {
    if (_homeReloadCallback != null) {
      _homeReloadCallback!();
    }
  }

  // ==================== WEB PUSH VAPID ====================

  /// Configura Web Push VAPID para notificações agendadas
  /// Sistema híbrido: VAPID primeiro, FCM como fallback
  Future<void> setupWebPushVAPID(String userId) async {
    try {
      debugPrint('[VAPID] Iniciando configuração Web Push...');

      // Verifica se é web e se tem suporte
      if (!kIsWeb) {
        debugPrint('[VAPID] Não é web, pulando configuração');
        return;
      }

      // Busca chave pública VAPID do backend
      final vapidPublicKey = await _getVapidPublicKey();
      if (vapidPublicKey == null) {
        debugPrint('[VAPID] Falha ao buscar chave pública, abortando');
        return;
      }

      debugPrint('[VAPID] Chave pública obtida');

      // Registra service worker (se ainda não estiver)
      await _registerServiceWorker();

      // Pede permissão de notificação
      final permission = await _requestNotificationPermission();
      if (permission != 'granted') {
        debugPrint('[VAPID] Permissão negada, abortando');
        return;
      }

      // Faz subscription no Push Manager
      final subscription = await _subscribeToWebPush(vapidPublicKey);
      if (subscription == null) {
        debugPrint('[VAPID] Falha ao criar subscription, abortando');
        return;
      }

      // Envia subscription para o backend
      await _sendSubscriptionToBackend(userId, subscription);

      debugPrint('[VAPID] ✅ Web Push configurado com sucesso!');
    } catch (e, stackTrace) {
      debugPrint('[VAPID] ❌ Erro ao configurar Web Push: $e');
      debugPrint('[VAPID] Stack trace: $stackTrace');
    }
  }

  Future<String?> _getVapidPublicKey() async {
    try {
      if (_apiService == null) return null;

      // Usa HTTP direto já que ApiService não tem método get genérico
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/vapid-public-key'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final publicKey = data['publicKey'] as String?;

        if (publicKey != null) {
          debugPrint('[VAPID] 🔑 Chave pública obtida do backend');
          debugPrint('[VAPID] 📏 Tamanho: ${publicKey.length} caracteres');
          debugPrint('[VAPID] 🔐 Primeiros 20 chars: ${publicKey.substring(0, 20)}...');
        }

        return publicKey;
      }

      debugPrint('[VAPID] ❌ Backend retornou status: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[VAPID] Erro ao buscar chave pública: $e');
      return null;
    }
  }

  Future<void> _registerServiceWorker() async {
    try {
      // Service worker já deve estar registrado pelo Flutter
      debugPrint('[VAPID] Service worker já registrado');
    } catch (e) {
      debugPrint('[VAPID] Erro ao registrar service worker: $e');
    }
  }

  Future<String> _requestNotificationPermission() async {
    try {
      // No web, usa API do navegador
      final result = await html.Notification.requestPermission();
      return result;
    } catch (e) {
      debugPrint('[VAPID] Erro ao pedir permissão: $e');
      return 'denied';
    }
  }

  Future<Map<String, dynamic>?> _subscribeToWebPush(String vapidPublicKey) async {
    try {
      if (!kIsWeb) return null;

      // Usa o wrapper JavaScript para criar subscription
      debugPrint('[VAPID] Criando subscription via JavaScript...');

      final subscription = await WebPushJSWrapper.subscribe(vapidPublicKey);

      if (subscription != null) {
        debugPrint('[VAPID] ✅ Subscription criada com sucesso!');
      } else {
        debugPrint('[VAPID] ❌ Falha ao criar subscription');
      }

      return subscription;
    } catch (e) {
      debugPrint('[VAPID] Erro ao criar subscription: $e');
      return null;
    }
  }

  Future<void> _sendSubscriptionToBackend(String userId, Map<String, dynamic> subscription) async {
    try {
      // Usa HTTP direto
      final token = await _authService?.getIdToken();
      if (token == null) {
        debugPrint('[VAPID] Token não disponível');
        return;
      }

      final response = await http.post(
        Uri.parse('https://barbearia-backend-service-862082955632.southamerica-east1.run.app/usuarios/$userId/webpush-subscription'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(subscription),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[VAPID] Subscription enviada ao backend');
      } else {
        debugPrint('[VAPID] Erro ao enviar subscription: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[VAPID] Erro ao enviar subscription: $e');
    }
  }

  /// Remove subscription VAPID do usuário
  Future<void> removeWebPushSubscription(String userId) async {
    try {
      if (!kIsWeb) return;

      // Cancela subscription no navegador
      if (kIsWeb) {
        try {
          final registration = await html.window.navigator.serviceWorker?.ready;
          final subscription = await registration?.pushManager?.getSubscription();
          await subscription?.unsubscribe();
        } catch (e) {
          debugPrint('[VAPID] Erro ao cancelar subscription no navegador: $e');
        }
      }

      // Remove do backend
      final token = await _authService?.getIdToken();
      if (token != null) {
        await http.delete(
          Uri.parse('https://barbearia-backend-service-862082955632.southamerica-east1.run.app/usuarios/$userId/webpush-subscription'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );
      }

      debugPrint('[VAPID] Subscription removida');
    } catch (e) {
      debugPrint('[VAPID] Erro ao remover subscription: $e');
    }
  }

  Future<void> forceRefreshToken() async {
    // CORREÇÃO AQUI: Verificando se 'currentUser' não é nulo, que é o jeito certo no seu código
    if (_authService?.currentUser == null) {
      debugPrint('🔥 REFRESH_TOKEN_DEBUG: Usuário não autenticado. Abortando refresh.');
      return;
    }

    debugPrint('🔥 REFRESH_TOKEN_DEBUG: Forçando atualização do token...');

    try {
      if (kIsWeb) {
        if (PlatformDetector.shouldUseAPNs) {
          debugPrint('🍎 REFRESH_TOKEN_DEBUG: Tentando obter novo token APNs (Safari).');
          await _initializeApnsWebPush();
        } else if (PlatformDetector.shouldUseFCM) {
          debugPrint('🔥 REFRESH_TOKEN_DEBUG: Tentando obter novo token FCM (Web).');
          final fcmToken = await _firebaseMessaging.getToken();
          if (fcmToken != null) {
            debugPrint('🔥 REFRESH_TOKEN_DEBUG: Novo token FCM obtido: ${fcmToken.substring(0, 20)}...');
            await _sendTokenToBackend(fcmToken);
          } else {
            debugPrint('🔥 REFRESH_TOKEN_DEBUG: Não foi possível obter um novo token FCM.');
          }
        }
      } else {
        // Lógica para Mobile (iOS/Android)
        debugPrint('🔥 REFRESH_TOKEN_DEBUG: Tentando obter novo token FCM (Mobile).');
        final fcmToken = await _firebaseMessaging.getToken();
        if (fcmToken != null) {
          debugPrint('🔥 REFRESH_TOKEN_DEBUG: Novo token FCM obtido: ${fcmToken.substring(0, 20)}...');
          await _sendTokenToBackend(fcmToken);
        } else {
          debugPrint('🔥 REFRESH_TOKEN_DEBUG: Não foi possível obter um novo token FCM.');
        }
      }
    } catch (e) {
      debugPrint('❌ REFRESH_TOKEN_DEBUG: Erro ao forçar a atualização do token: $e');
    }
  }

  @override
  void dispose() {
    _notificationStreamController.close();
    _notifications.clear();
    super.dispose();
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('//======================================================//');
  debugPrint('// 📲 NOVA NOTIFICAÇÃO RECEBIDA (ORIGEM: BACKGROUND)');
  debugPrint('//======================================================//');
  
  if (message.notification != null) {
    debugPrint('   [notification -> title]: "${message.notification?.title}"');
    debugPrint('   [notification -> body]:  "${message.notification?.body}"');
  } else {
    debugPrint('   [notification]: null');
  }

  if (message.data.isNotEmpty) {
    debugPrint('   [data -> payload]:');
    message.data.forEach((key, value) {
      debugPrint('     - $key: "$value"');
    });
  } else {
    debugPrint('   [data -> payload]: Vazio');
  }
  debugPrint('//======================================================//');
}