// lib/widgets/auth_wrapper.dart

import 'package:analicegrubert/models/usuario.dart';
import 'package:analicegrubert/screens/home_page.dart';
import 'package:analicegrubert/screens/login_page.dart';
import 'package:analicegrubert/screens/main_layout.dart';
import 'package:analicegrubert/screens/consentimento_page.dart';
import 'package:analicegrubert/screens/client_dashboard.dart';
import 'package:analicegrubert/screens/medico_dashboard_page.dart';
import 'package:analicegrubert/screens/loading_screen.dart';
import 'package:analicegrubert/services/auth_service.dart';
import 'package:analicegrubert/services/notification_service.dart';
import 'package:analicegrubert/widgets/server_error_banner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

// PASSO 1: Adicionar "with WidgetsBindingObserver" para escutar o ciclo de vida do app
class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  
  // Flag para garantir que a inicialização só aconteça uma vez por login
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    // Registra este widget como um observador do ciclo de vida
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Remove o observador para evitar vazamentos de memória
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // PASSO 2: Executar uma ação quando o estado do app mudar
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Se o app foi reaberto (estava em segundo plano e voltou a ficar ativo)
    if (state == AppLifecycleState.resumed) {
      debugPrint("✅ AppLifecycle: App voltou para o primeiro plano (resumed).");
      // Chama nossa função para forçar a atualização do token
      _refreshToken();
    }
  }

  // PASSO 3: Criar a função que chama o serviço de notificação
  void _refreshToken() {
    try {
      // Pega a instância do NotificationService sem reconstruir o widget
      final notificationService = context.read<NotificationService>();
      // Chama a função que criamos no passo anterior
      notificationService.forceRefreshToken();
    } catch (e) {
      debugPrint("❌ Erro ao chamar refreshToken no AuthWrapper: $e");
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = context.watch<AuthService>();
    
    // A lógica de inicialização agora checa se o usuário mudou
    if (authService.currentUser != null && !_servicesInitialized) {
      _initializeServices(authService);
      _servicesInitialized = true;
    } else if (authService.currentUser == null) {
      // Reseta a flag no logout
      _servicesInitialized = false;
    }
  }

  void _initializeServices(AuthService authService) {
    final notificationService = context.read<NotificationService>();
    notificationService.setNavigationContext(context);

    // Bloquear notificações para super_admin
    if (authService.currentUser?.isSuperAdmin ?? false) {
      debugPrint('🔥 WRAPPER_DEBUG: Super admin detectado - notificações desabilitadas');
      return;
    }

    // A inicialização do NotificationService só acontece uma vez por login
    if (!notificationService.isInitialized) {
      debugPrint('🔥 WRAPPER_DEBUG: Usuário autenticado. Inicializando NotificationService...');
      notificationService.initialize(authService);
    } else {
      debugPrint('🔥 WRAPPER_DEBUG: NotificationService já inicializado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final user = authService.currentUser;
        final authStream = authService.authStateChanges;
        final isSyncing = authService.isSyncing;

        return StreamBuilder<User?>(
          stream: authStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && user == null) {
              return const LoadingScreen(message: 'Verificando autenticação...');
            }

            if (isSyncing) {
              return const LoadingScreen(message: 'Sincronizando perfil...');
            }
            
            if (user == null) {
              // Garante que o estado de inicialização seja resetado no logout
              if (_servicesInitialized) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    _servicesInitialized = false;
                  });
                });
              }
              return const LoginPage();
            }

            if (snapshot.hasData) {
              // Verificar super_admin PRIMEIRO (acesso total como admin, sem notificações)
              if (user.isSuperAdmin) {
                return const ServerErrorBanner(child: MainLayout());
              }

              const negocioId = "AvcbtyokbHx82pYbiraE";
              final userRole = user.roles?[negocioId];

              if (userRole == null || userRole == 'paciente' || userRole == 'cliente') {
                if (user.consentimentoLgpd != true) {
                  return const ConsentimentoPage();
                }
              }

              if (userRole == 'admin') {
                return const ServerErrorBanner(child: MainLayout());
              } else if (userRole == 'medico') {
                return const ServerErrorBanner(child: MedicoDashboardPage());
              } else if (userRole == null || userRole == 'cliente') {
                return const ServerErrorBanner(child: ClientDashboard());
              } else {
                return const ServerErrorBanner(child: HomePage());
              }
            }
            
            return const LoginPage();
          },
        );
      },
    );
  }
}