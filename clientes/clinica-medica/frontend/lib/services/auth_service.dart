// lib/services/auth_service.dart

import 'package:analicegrubert/api/api_service.dart';
import 'package:analicegrubert/config/app_config.dart';
import 'package:analicegrubert/models/usuario.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:analicegrubert/services/notification_service.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  Usuario? _currentUser;
  bool _hasServerError = false;
  bool _isSyncing = false;
  late ApiService _apiService; // CORRIGIDO

  Usuario? get currentUser => _currentUser;
  String? get currentUserId => _firebaseAuth.currentUser?.uid;
  bool get hasServerError => _hasServerError;
  bool get isSyncing => _isSyncing;

  // LINHA QUE A MULA AQUI APAGOU, AGORA DE VOLTA
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  void updateCurrentUser(Usuario updatedUser) {
    _currentUser = updatedUser;
    notifyListeners();
  }

  AuthService() {
    _apiService = ApiService(authService: this); // CORRIGIDO
    try {
      _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
    } catch (e) {
      // Continua funcionando mesmo com erro do Firebase
    }
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
    } else {
      await _fetchAndSetUser(firebaseUser);
    }
    notifyListeners();
  }

  Future<void> _fetchAndSetUser(User firebaseUser) async {
    if (_isSyncing) {
      return;
    }
    
    _isSyncing = true;
    notifyListeners();
    try {
      final negocioId = await getNegocioId();
      final syncData = {
        'nome': firebaseUser.displayName ?? firebaseUser.email ?? 'Usuário Sem Nome',
        'email': firebaseUser.email,
        'firebase_uid': firebaseUser.uid,
        'negocio_id': negocioId,
      };

      final responseBody = await _apiService.syncProfile(syncData);
      _currentUser = responseBody;
      _hasServerError = false;

      // Bloquear notificações para super_admin
      if (!(_currentUser?.isSuperAdmin ?? false)) {
        // Configura Web Push VAPID para notificações agendadas (híbrido com FCM)
        try {
          final notificationService = NotificationService();
          // Usa o ID do Firestore (não o Firebase UID)
          final userId = _currentUser?.id;
          if (userId != null && userId.isNotEmpty) {
            await notificationService.setupWebPushVAPID(userId);
          } else {
            debugPrint('⚠️ ID do usuário não disponível para Web Push VAPID');
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao configurar Web Push VAPID (usando FCM como fallback): $e');
          // Continua normalmente - FCM será usado como fallback automático
        }
      } else {
        debugPrint('🔥 AUTH_DEBUG: Super admin detectado - Web Push VAPID desabilitado');
      }
    } catch (e) {
      _hasServerError = true;
      final negocioId = await getNegocioId();
      _currentUser = Usuario(
        id: firebaseUser.uid,
        firebaseUid: firebaseUser.uid,
        email: firebaseUser.email,
        nome: firebaseUser.displayName ?? firebaseUser.email ?? 'Usuário',
        roles: {negocioId ?? 'default': 'cliente'},
      );
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      // Garantir persistência da sessão (usuário fica logado indefinidamente até fazer logout manual)
      if (kIsWeb) {
        await _firebaseAuth.setPersistence(Persistence.LOCAL);
      }

      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // Configurar ActionCodeSettings para redirecionar para a página de reset
      // Para web, usamos a URL atual do aplicativo
      final port = Uri.base.port;
      final portString = (port != 0 && port != 80 && port != 443) ? ':$port' : '';

      final actionCodeSettings = ActionCodeSettings(
        // URL base do seu app web - ALTERE PARA SEU DOMÍNIO EM PRODUÇÃO
        url: kIsWeb
            ? '${Uri.base.scheme}://${Uri.base.host}$portString/#/reset-password'
            : 'https://seudominio.com/#/reset-password',
        handleCodeInApp: true,
      );

      await _firebaseAuth.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );
    } on FirebaseAuthException {
      rethrow;
    }
  }
  
  Future<void> updateFirebaseProfile({String? displayName, String? photoURL}) async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.updateProfile(displayName: displayName, photoURL: photoURL);
      await user.reload(); 
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _firebaseAuth.currentUser;
    final userEmail = user?.email;

    if (user != null && userEmail != null) {
      AuthCredential credential = EmailAuthProvider.credential(
        email: userEmail, 
        password: currentPassword
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } else {
      throw Exception('Nenhum usuário logado para alterar a senha.');
    }
  }

  Future<void> storeNegocioId(String negocioId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('negocioId', negocioId);
  }

  Future<String?> getNegocioId() async {
    // Usa o negocioId da configuração do cliente
    return AppConfig.negocioId;
  }

  void updateCurrentUserData(Usuario updatedUser) {
    _currentUser = updatedUser;
    notifyListeners();
  }

  Future<void> refreshCurrentUser() async {
    if (_isSyncing) {
      return;
    }
    
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser != null) {
      _isSyncing = true;
      try {
        final responseBody = await _apiService.getCurrentUserProfile();
        
        if (responseBody != null) {
          _currentUser = responseBody;
        } else {
          await _fetchAndSetUser(firebaseUser);
        }
      } catch (e) {
        await _fetchAndSetUser(firebaseUser);
      } finally {
        _isSyncing = false;
      }
      
      notifyListeners();
    }
  }

  Future<String?> getIdToken() async {
    final User? user = _firebaseAuth.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      return token;
    }
    return null;
  }

  Future<void> signOut() async {
    debugPrint('🚀 LOGOUT_DEBUG: Iniciando processo de signOut...');

    final notificationService = NotificationService();
    final fcmToken = notificationService.fcmToken;

    if (fcmToken != null) {
      try {
        await _apiService.logoutFromBackend(fcmToken);
      } catch (e) {
        debugPrint('❌ LOGOUT_DEBUG: Erro ao chamar o endpoint de logout do backend, mas continuando com o signOut do Firebase. Erro: $e');
      }
    } else {
      debugPrint('⚠️ LOGOUT_DEBUG: Token FCM não encontrado, pulando chamada ao backend.');
    }

    await _firebaseAuth.signOut();
    _currentUser = null;
    debugPrint('✅ LOGOUT_DEBUG: Usuário deslogado do Firebase com sucesso.');
    notifyListeners();
  }
}