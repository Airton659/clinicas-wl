// lib/providers/notification_provider.dart

import 'package:flutter/foundation.dart';
import '../models/notificacao.dart';
import '../api/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final ApiService _apiService;
  final AuthService _authService;
  final NotificationService? _notificationService;

  List<Notificacao> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _disposed = false;

  NotificationProvider({
    required ApiService apiService,
    required AuthService authService,
    NotificationService? notificationService,
  })  : _apiService = apiService,
        _authService = authService,
        _notificationService = notificationService {
    // Auto-registrar no NotificationService se fornecido
    if (_notificationService != null) {
      debugPrint('🔗 NotificationProvider auto-registrando no NotificationService');
      _notificationService!.setNotificationProvider(this);
    }
    _initialize();
  }

  // Getters
  List<Notificacao> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  void _initialize() {
    // Escutar mudanças no AuthService para recarregar notificações
    _authService.addListener(_onAuthChanged);
    
    if (_authService.currentUser != null) {
      loadNotifications();
    }
  }

  void _onAuthChanged() {
    if (_authService.currentUser != null) {
      loadNotifications();
    } else {
      _clearNotifications();
    }
  }

  void _clearNotifications() {
    _notifications = [];
    _unreadCount = 0;
    _safeNotifyListeners();
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> loadNotifications({bool forceRefresh = false}) async {
    if (_authService.currentUser == null) {
      debugPrint('⚠️ [NotificationProvider] loadNotifications abortado - usuário não logado');
      return;
    }

    try {
      _isLoading = true;
      _safeNotifyListeners();

      debugPrint('📥 [NotificationProvider] Buscando notificações (forceRefresh: $forceRefresh)...');
      final notifications = await _apiService.getNotificacoes(forceRefresh: forceRefresh);
      final unreadCount = await _apiService.getNotificacoesNaoLidasContagem();

      debugPrint('📊 [NotificationProvider] Recebido: ${notifications.length} notificações, $unreadCount não lidas');

      _notifications = notifications;
      _unreadCount = unreadCount;

      debugPrint('✅ [NotificationProvider] Estado atualizado, notificando listeners...');

    } catch (e) {
      debugPrint('❌ [NotificationProvider] Erro ao carregar notificações: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _apiService.marcarNotificacaoComoLida(notificationId);
      
      // Atualizar estado local
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].lida) {
        _notifications[index] = _notifications[index].copyWith(lida: true);
        _unreadCount = (_unreadCount - 1).clamp(0, double.infinity).toInt();
        _safeNotifyListeners();
      }
    } catch (e) {
      throw e;
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiService.marcarTodasNotificacoesComoLidas();
      
      // Atualizar estado local
      _notifications = _notifications.map((n) => n.copyWith(lida: true)).toList();
      _unreadCount = 0;
      _safeNotifyListeners();
    } catch (e) {
      throw e;
    }
  }

  Future<void> scheduleNotification({
    required String patientId,
    required String title,
    required String message,
    required DateTime scheduledDate,
  }) async {
    try {
      await _apiService.agendarNotificacao(
        pacienteId: patientId,
        titulo: title,
        mensagem: message,
        dataAgendamento: scheduledDate,
      );
      
    } catch (e) {
      throw e;
    }
  }

  void onNewNotificationReceived() {
    // Método chamado quando uma nova notificação é recebida via FCM
    debugPrint('🔔 [NotificationProvider] onNewNotificationReceived() chamado');
    debugPrint('   - User logado: ${_authService.currentUser?.email}');
    debugPrint('   - Carregando notificações com forceRefresh...');
    loadNotifications(forceRefresh: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }
}