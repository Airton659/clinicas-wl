// lib/screens/home_page.dart

import 'dart:async';
import 'package:analicegrubert/models/notification_types.dart';
import 'package:analicegrubert/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../api/api_service.dart';
import '../models/usuario.dart';
import '../models/role.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/modern_widgets.dart';
import '../widgets/simple_offline_indicator.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/notification_badge.dart';
import '../widgets/notification_permission_banner.dart';
import '../widgets/permission_guard.dart';
import '../providers/permissions_provider.dart';
import 'add_patient_page.dart';
import 'notifications_page.dart';
import 'patient_details_page.dart';
import 'patient_list_page.dart';
import 'team_management_page.dart';
import 'profile_settings_page.dart';
import 'super_admin_dashboard_page.dart';
import '../models/paciente.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late Future<List<dynamic>> _dataFuture;
  String? userRole;
  String? userName;
  late AnimationController _headerAnimationController;
  late AnimationController _cardsAnimationController;
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _headerFadeAnimation;
  int _rebuildKey = 0;
  bool _isRefreshing = false;
  Map<String, Role> _rolesCache = {}; // Cache completo dos perfis por tipo

  // ADICIONADO: Variável para controlar o "ouvinte" de notificações
  late StreamSubscription<NotificationType?> _notificationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAnimations();
    _initializeData();
    // ADICIONADO: Inicia o "ouvinte" de notificações
    _setupNotificationListener();
  }

  // ADICIONADO: Método para configurar o "ouvinte" de notificações
  void _setupNotificationListener() {
    final notificationService = NotificationService();
    _notificationSubscription =
        notificationService.notificationStream.listen((notificationType) {
      // Define uma lista de notificações que devem recarregar a HomePage
      // ✅ Apenas notificações ATIVAS (removido checklistConcluido e novoRegistroDiario)
      final relevantTypes = [
        NotificationType.relatorioAvaliado,
        NotificationType.planoAtualizado,
        NotificationType.associacaoProfissional,
        NotificationType.tarefaAtrasada,
        NotificationType.tarefaAtrasadaTecnico,
        NotificationType.tarefaConcluida,
        // ❌ DESABILITADO: NotificationType.checklistConcluido,
        // ❌ DESABILITADO: NotificationType.novoRegistroDiario,
      ];

      if (relevantTypes.contains(notificationType)) {
        debugPrint(
            "✅ Notificação relevante [${notificationType?.toString().split('.').last}] recebida, atualizando a Home Page...");
        if (mounted) {
          // Chama o método que já existe para recarregar os dados
          _reloadData(forceRefresh: true);
          // Atualiza o contador de notificações no ícone do sino
          Provider.of<NotificationProvider>(context, listen: false)
              .loadNotifications(forceRefresh: true);
        }
      }
    });
  }

  void _setupAnimations() {
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _cardsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _headerSlideAnimation = Tween<double>(
      begin: -50,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _headerFadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOut,
    ));

    _headerAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _cardsAnimationController.forward();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _headerAnimationController.dispose();
    _cardsAnimationController.dispose();
    // ADICIONADO: Cancela a inscrição para evitar vazamento de memória
    _notificationSubscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Recarrega dados quando o app volta ao foco
    if (state == AppLifecycleState.resumed) {
      _reloadData(forceRefresh: true);
    }
  }

  void _initializeData() {
    final authService = Provider.of<AuthService>(context, listen: false);
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    final currentUser = authService.currentUser;
    final rolesMap = currentUser?.roles;
    userName = currentUser?.nome ?? 'Usuário';

    // Super admin deve ser tratado como admin
    if (currentUser?.isSuperAdmin ?? false) {
      userRole = 'admin';
    } else if (rolesMap != null) {
      userRole = rolesMap[negocioId];
    }

    // REMOVIDO: O callback antigo foi substituído pelo listener
    // final notificationService = NotificationService();
    // notificationService.setHomeReloadCallback(() {
    //   if (mounted) {
    //     _reloadData(forceRefresh: true);
    //   }
    // });

    // Carregar nomes dos perfis ANTES de carregar dados se for admin
    if (userRole == 'admin') {
      _loadRoleNames().then((_) => _reloadData());
    } else {
      _reloadData();
    }
  }

  Future<void> _loadRoleNames() async {
    try {
      final permissionsProvider =
          Provider.of<PermissionsProvider>(context, listen: false);
      await permissionsProvider.carregarRoles("rlAB6phw0EBsBFeDyOt6");

      if (mounted) {
        setState(() {
          // Criar mapa tipo -> objeto Role completo
          for (final role in permissionsProvider.negocioRoles) {
            _rolesCache[role.tipo] = role;
          }
          debugPrint('🔍 _rolesCache carregado: ${_rolesCache.keys.toList()}');
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar perfis: $e');
    }
  }

  void _reloadData({bool forceRefresh = false}) {
    final apiService = Provider.of<ApiService>(context, listen: false);

    // Limpa cache agressivamente quando forceRefresh é true
    if (forceRefresh) {
      apiService.clearCache('getAllUsersInBusiness');
      apiService.clearCache('getPacientes');
      apiService.clearCache(); // Limpa todo o cache
      _rebuildKey++; // Força rebuild completo do widget
    }

    setState(() {
      // Marca como refreshing DENTRO do setState para garantir que seja aplicado imediatamente
      if (forceRefresh) {
        _isRefreshing = true;
      }
      if (userRole == 'admin') {
        _dataFuture =
            apiService.getAllUsersInBusiness(forceRefresh: forceRefresh);
      } else if (userRole == 'medico') {
        // Médicos só veem pacientes associados a eles
        // O backend deve filtrar automaticamente baseado no usuário logado
        _dataFuture = apiService.getPacientes(forceRefresh: forceRefresh);
      } else {
        _dataFuture = apiService.getPacientes(forceRefresh: forceRefresh);
      }

      // Executa cache predictivo baseado no contexto
      _dataFuture.then((data) {
        if (mounted && _isRefreshing) {
          setState(() {
            _isRefreshing = false;
          });
        }
        apiService.preloadRelatedData('home_screen', userRole: userRole);
      }).catchError((e) {
        if (mounted && _isRefreshing) {
          setState(() {
            _isRefreshing = false;
          });
        }
        // Silenciosamente ignora erros de cache predictivo
      });
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String _getRoleDisplayName(String? role) {
    switch (role) {
      case 'admin':
        return 'Gestor';
      case 'profissional':
        return 'Enfermeiro';
      case 'tecnico':
        return 'Técnico';
      case 'medico':
        return 'Médico';
      case 'cliente':
        return 'Paciente';
      default:
        return 'Usuário';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimpleOfflineIndicator(
      child: Scaffold(
        backgroundColor: AppTheme.neutralGray50,
        body: CustomScrollView(
          slivers: [
            _buildModernAppBar(),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const NotificationPermissionBanner(),
                  if (userRole == 'admin')
                    _buildAdminDashboard()
                  else
                    _buildUserDashboard(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: FlexibleSpaceBar(
          background: AnimatedBuilder(
            animation: _headerAnimationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _headerSlideAnimation.value),
                child: Opacity(
                  opacity: _headerFadeAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
                    child: Row(
                      children: [
                        // Avatar do usuário
                        Consumer<AuthService>(
                          builder: (context, authService, child) {
                            return ProfileAvatar(
                              imageUrl: authService.currentUser?.profileImage,
                              userName: authService.currentUser?.nome,
                              radius: 30,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ProfileSettingsPage(),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        // Informações do usuário
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                _getGreeting(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userName ?? 'Usuário',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              StatusBadge(
                                text: _getRoleDisplayName(userRole),
                                color: Colors.white,
                                isOutlined: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      actions: [
        // BOTÃO PARA NOTIFICAÇÕES
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: NotificationIconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsPage(),
                ),
              );
            },
          ),
        ),
        // BOTÃO SUPER ADMIN (visível apenas para role="platform")
        if (Provider.of<AuthService>(context, listen: false)
                .currentUser
                ?.isSuperAdmin ??
            false)
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SuperAdminDashboardPage(),
                  ),
                );
              },
              icon: const Icon(Icons.verified_user, color: Colors.amber),
              tooltip: 'Super Admin Dashboard',
              style: IconButton.styleFrom(
                backgroundColor: Colors.deepPurple.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        // BOTÃO PARA CONFIGURAÇÕES DO PERFIL
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ProfileSettingsPage()),
              );
            },
            icon: const Icon(Icons.settings_rounded, color: Colors.white),
            tooltip: 'Configurações do Perfil',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: IconButton(
            onPressed: () {
              Provider.of<AuthService>(context, listen: false).signOut();
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Sair',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminDashboard() {
    return RefreshIndicator(
      onRefresh: () async {
        _reloadData(forceRefresh: true);
        // Espera um pouco para a nova Future começar
        await Future.delayed(const Duration(milliseconds: 100));
      },
      child: FutureBuilder<List<dynamic>>(
        key: ValueKey(_rebuildKey),
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingDashboard();
          }
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyAdminDashboard();
          }

          final allUsers = snapshot.data!.cast<Usuario>();
          return _buildAdminContent(allUsers);
        },
      ),
    );
  }

  List<_AlertCard> _buildDynamicAlerts(List<Usuario> allUsers) {
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    final List<_AlertCard> alerts = [];

    // Filtra pacientes
    final patients = allUsers
        .where((u) => !u.isSuperAdmin && u.roles?[negocioId] == 'cliente')
        .toList();

    // Filtra perfis customizados (não system)
    final customRoles = _rolesCache.values.where((r) => !r.isSystem).toList();

    for (var role in customRoles) {
      if (role.id == null) continue;

      // Conta pacientes sem associação para este perfil
      final count =
          patients.where((p) => p.getAssociationCount(role.id!) == 0).length;

      if (count > 0) {
        alerts.add(
          _AlertCard(
            title: 'Pacientes sem ${role.nomeCustomizado}',
            count: count,
            icon: _getIconFromString(role.icone),
            color: _getColorFromHex(role.cor),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PatientListPage(
                    filterByMissingAssociation: role.id,
                  ),
                ),
              ).then((_) async {
                await Future.delayed(const Duration(milliseconds: 100));
                if (mounted) {
                  _reloadData(forceRefresh: true);
                }
              });
            },
          ),
        );
      }
    }
    return alerts;
  }

  Widget _buildAdminContent(List<Usuario> allUsers) {
    const negocioId = "rlAB6phw0EBsBFeDyOt6";

    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🏗️  CONSTRUINDO DASHBOARD ADMIN');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('📊 Total usuários: ${allUsers.length}');
    debugPrint('🗂️  _rolesCache: ${_rolesCache.keys.toList()}');

    // Sempre mostra pacientes
    final totalPacientes = allUsers
        .where((u) => !u.isSuperAdmin && u.roles?[negocioId] == 'cliente')
        .length;

    // Contadores dinâmicos baseados nos perfis que existem
    Map<String, int> roleCount = {};

    // Adiciona contador para 'cliente' (Pacientes)
    roleCount['cliente'] = totalPacientes;

    // Adiciona contadores para roles customizadas
    for (var roleType in _rolesCache.keys) {
      roleCount[roleType] = allUsers
          .where((u) => !u.isSuperAdmin && u.roles?[negocioId] == roleType)
          .length;
    }

    debugPrint('📈 roleCount calculado: $roleCount');
    debugPrint('═══════════════════════════════════════════════════════════');

    final dynamicAlerts = _buildDynamicAlerts(allUsers);

    return AnimatedBuilder(
      animation: _cardsAnimationController,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Visão Geral', Icons.dashboard_rounded),
              const SizedBox(height: 16),
              _buildStatsGrid(
                  _buildDynamicRoleCards(roleCount, totalPacientes)),
              const SizedBox(height: 32),
              _buildSectionHeader(
                  'Alertas e Pendências', Icons.warning_amber_rounded),
              const SizedBox(height: 16),

              // Mostra loading durante refresh
              if (_isRefreshing) ...[
                ModernCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Atualizando...',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Verificando pendências.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.neutralGray600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (dynamicAlerts.isNotEmpty) ...[
                _buildAlertsGrid(dynamicAlerts),
              ] else ...[
                ModernCard(
                  hasGradient: true,
                  gradientColors: [
                    AppTheme.successGreen.withOpacity(0.1),
                    Colors.white
                  ],
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.successGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tudo em ordem!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.successGreen,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Não há pendências no momento.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.neutralGray600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              _buildSectionHeader('Ações Rápidas', Icons.flash_on_rounded),
              const SizedBox(height: 16),
              _buildQuickActions(),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserDashboard() {
    return RefreshIndicator(
      onRefresh: () async {
        _reloadData(forceRefresh: true);
        // Espera um pouco para a nova Future começar
        await Future.delayed(const Duration(milliseconds: 100));
      },
      child: FutureBuilder<List<dynamic>>(
        key: ValueKey(_rebuildKey),
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingPatients();
          }
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyPatientsState();
          }

          return AnimatedBuilder(
            animation: _cardsAnimationController,
            builder: (context, child) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                            'Meus Pacientes', Icons.people_rounded),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  _buildPatientsList(snapshot.data!),
                  const SizedBox(height: 100),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.neutralGray800,
          ),
        ),
      ],
    );
  }

  IconData _getIconFromString(String? iconeName) {
    debugPrint('🎨 Convertendo ícone: "$iconeName"');

    // Mapa completo de ícones
    final iconMap = {
      'person': Icons.person,
      'person_outline': Icons.person_outline,
      'account_circle': Icons.account_circle,
      'face': Icons.face,
      'medical_services': Icons.medical_services,
      'local_hospital': Icons.local_hospital,
      'health_and_safety': Icons.health_and_safety,
      'science': Icons.science,
      'medication': Icons.medication,
      'vaccines': Icons.vaccines,
      'favorite': Icons.favorite,
      'healing': Icons.healing,
      'monitor_heart': Icons.monitor_heart,
      'psychology': Icons.psychology,
      'sports_martial_arts': Icons.sports_martial_arts,
      'accessibility_new': Icons.accessibility_new,
      'elderly': Icons.elderly,
      'people_alt': Icons.people_alt,
      'groups': Icons.groups,
      'supervisor_account': Icons.supervisor_account,
      'business_center': Icons.business_center,
      'badge': Icons.badge,
      'work': Icons.work,
      'engineering': Icons.engineering,
      'construction': Icons.construction,
      'agriculture': Icons.agriculture,
      'handyman': Icons.handyman,
      'build': Icons.build,
      'medical_information': Icons.medical_information,
      'assignment': Icons.assignment,
      'assignment_ind': Icons.assignment_ind,
      'verified_user': Icons.verified_user,
      'security': Icons.security,
      'shield': Icons.shield,
      'admin_panel_settings': Icons.admin_panel_settings,
      'manage_accounts': Icons.manage_accounts,
    };

    final result = iconMap[iconeName] ?? Icons.people_alt_rounded;
    debugPrint(
        '   → Resultado: ${result == Icons.people_alt_rounded ? "DEFAULT (not found)" : "FOUND"}');

    return result;
  }

  Color _getColorFromHex(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return AppTheme.primaryBlue;
    }

    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return AppTheme.primaryBlue;
    }
  }

  List<_StatCard> _buildDynamicRoleCards(
      Map<String, int> roleCount, int totalPacientes) {
    List<_StatCard> cards = [];

    for (var entry in roleCount.entries) {
      final roleType = entry.key;
      final count = entry.value;

      // Pular admin (é perfil do sistema)
      if (roleType == 'admin') continue;

      // Tratamento especial para 'cliente' (Pacientes)
      if (roleType == 'cliente') {
        cards.add(_StatCard(
          title: 'Pacientes',
          value: count.toString(),
          icon: Icons.person,
          color: const Color(0xFF1976D2), // Azul
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TeamManagementPage(initialRoleFilter: 'cliente'),
            ),
          ),
        ));
        continue;
      }

      // Buscar dados do perfil no cache
      final role = _rolesCache[roleType];

      if (role != null) {
        // Criar card com dados do perfil
        cards.add(_StatCard(
          title: role.nomeCustomizado,
          value: count.toString(),
          icon: _getIconFromString(role.icone),
          color: _getColorFromHex(role.cor),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TeamManagementPage(initialRoleFilter: roleType),
            ),
          ),
        ));
      }
    }

    debugPrint('🃏 Cards criados: ${cards.length} (roleCount: $roleCount)');

    return cards;
  }

  Widget _buildStatsGrid(List<_StatCard> stats) {
    return StaggeredGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: stats.map((stat) {
        return StaggeredGridTile.fit(
          crossAxisCellCount: 1,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 600 + (stats.indexOf(stat) * 100)),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: ModernCard(
                  onTap: stat.onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: stat.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(stat.icon, color: stat.color, size: 24),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        stat.value,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: stat.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stat.title,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.neutralGray600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAlertsGrid(List<_AlertCard> alerts) {
    return Column(
      children: alerts.map((alert) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 600 + (alerts.indexOf(alert) * 100)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(50 * (1 - value), 0),
              child: Opacity(
                opacity: value,
                child: ModernCard(
                  margin: const EdgeInsets.only(bottom: 16),
                  onTap: alert.onTap,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: alert.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(alert.icon, color: alert.color, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.neutralGray800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Verificar lista',
                              style: TextStyle(
                                fontSize: 14,
                                color: alert.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: alert.color,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(
        title: 'Novo Usuário',
        subtitle: 'Cadastrar paciente, técnico ou enfermeiro',
        icon: Icons.person_add_rounded,
        color: AppTheme.primaryBlue,
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const AddPatientPage()),
          );
          if (result == true) _reloadData();
        },
      ),
      _QuickAction(
        title: 'Gerenciar Vínculos',
        subtitle: 'Associar pacientes, enfermeiros e técnicos',
        icon: Icons.link_rounded,
        color: AppTheme.accentTeal,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TeamManagementPage()),
          );
        },
      ),
    ];

    return Column(
      children: actions.map((action) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration:
              Duration(milliseconds: 800 + (actions.indexOf(action) * 100)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(30 * (1 - value), 0),
              child: Opacity(
                opacity: value,
                child: ModernCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  onTap: action.onTap,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              action.color,
                              action.color.withOpacity(0.8)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(action.icon, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              action.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.neutralGray800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              action.subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.neutralGray500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppTheme.neutralGray400,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildPatientsList(List<dynamic> patients) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: patients.length,
      itemBuilder: (context, index) {
        final patient = patients[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 600 + (index * 100)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(50 * (1 - value), 0),
              child: Opacity(
                opacity: value,
                child: _buildEnhancedPatientCard(patient),
              ),
            );
          },
        );
      },
    );
  }

  // Em lib/screens/home_page.dart

  Widget _buildEnhancedPatientCard(dynamic patient) {
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    bool isInactive = false;
    if (patient.runtimeType.toString().contains('Usuario') &&
        patient.status_por_negocio != null) {
      isInactive = patient.status_por_negocio?[negocioId] == 'inativo';
    }
    final displayName = patient.nome ?? 'Paciente';

    // Pega a URL da foto do campo correto que acabamos de adicionar
    final imageUrl = (patient is Paciente) ? patient.profileImageUrl : null;

    return ModernCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientDetailsPage(
              pacienteId: patient.id,
              pacienteNome: patient.nome,
            ),
          ),
        );
      },
      child: Column(
        children: [
          Row(
            children: [
              // AGORA SIM, COM O CAMPO CORRETO
              ModernAvatar(
                name: displayName,
                imageUrl: imageUrl,
                radius: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isInactive
                                  ? AppTheme.neutralGray500
                                  : AppTheme.neutralGray800,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (isInactive)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'INATIVO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.errorRed,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 14,
                          color: isInactive
                              ? AppTheme.neutralGray400
                              : AppTheme.neutralGray500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            patient.email ?? 'Email não informado',
                            style: TextStyle(
                              fontSize: 12,
                              color: isInactive
                                  ? AppTheme.neutralGray400
                                  : AppTheme.neutralGray500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isInactive
                    ? AppTheme.neutralGray400
                    : AppTheme.neutralGray500,
                size: 16,
              ),
            ],
          ),
          if (_hasLinkedProfessionalsHome(patient)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.neutralGray50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.neutralGray200),
              ),
              child: _buildLinkedProfessionalsHome(patient, isInactive),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasLinkedProfessionalsHome(dynamic patient) {
    // Verifica se o objeto tem as propriedades antes de acessá-las
    final hasEnfermeiro = patient.runtimeType.toString().contains('Usuario') &&
        patient.enfermeiroId != null &&
        patient.enfermeiroId!.isNotEmpty;
    final hasTecnicos = patient.runtimeType.toString().contains('Usuario') &&
        patient.tecnicosIds != null &&
        patient.tecnicosIds!.isNotEmpty;
    return hasEnfermeiro || hasTecnicos;
  }

  Widget _buildLinkedProfessionalsHome(dynamic patient, bool isInactive) {
    final List<Widget> professionals = [];

    if (patient.runtimeType.toString().contains('Usuario') &&
        patient.enfermeiroId != null &&
        patient.enfermeiroId!.isNotEmpty) {
      professionals.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isInactive
                    ? AppTheme.neutralGray200
                    : AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.health_and_safety_outlined,
                size: 14,
                color:
                    isInactive ? AppTheme.neutralGray400 : AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Enfermeiro vinculado',
              style: TextStyle(
                fontSize: 12,
                color:
                    isInactive ? AppTheme.neutralGray400 : AppTheme.primaryBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (patient.runtimeType.toString().contains('Usuario') &&
        patient.tecnicosIds != null &&
        patient.tecnicosIds!.isNotEmpty) {
      if (professionals.isNotEmpty) {
        professionals.add(const SizedBox(height: 8));
      }
      professionals.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isInactive
                    ? AppTheme.neutralGray200
                    : AppTheme.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.medical_services_outlined,
                size: 14,
                color: isInactive
                    ? AppTheme.neutralGray400
                    : AppTheme.successGreen,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${patient.tecnicosIds!.length} técnico${patient.tecnicosIds!.length > 1 ? 's' : ''} vinculado${patient.tecnicosIds!.length > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: isInactive
                    ? AppTheme.neutralGray400
                    : AppTheme.successGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: professionals,
    );
  }

  Widget _buildLoadingDashboard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionHeader('Carregando...', Icons.dashboard_rounded),
          const SizedBox(height: 16),
          StaggeredGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: List.generate(4, (index) {
              return StaggeredGridTile.fit(
                crossAxisCellCount: 1,
                child: ShimmerLoading(
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPatients() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionHeader('Carregando...', Icons.people_rounded),
          const SizedBox(height: 16),
          ...List.generate(5, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ShimmerLoading(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return ModernEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Ops! Algo deu errado',
      subtitle:
          'Não conseguimos carregar os dados.\nTente novamente em alguns instantes.',
      buttonText: 'Tentar Novamente',
      onButtonPressed: () => _reloadData(forceRefresh: true),
    );
  }

  Widget _buildEmptyAdminDashboard() {
    return const ModernEmptyState(
      icon: Icons.dashboard_rounded,
      title: 'Dashboard Vazio',
      subtitle: 'Não há dados para exibir no momento.',
    );
  }

  Widget _buildEmptyPatientsState() {
    return ModernEmptyState(
      icon: Icons.people_outline_rounded,
      title: 'Nenhum Paciente',
      subtitle: userRole == 'profissional'
          ? 'Você ainda não tem pacientes vinculados.\nComece adicionando um novo paciente!'
          : 'Não há pacientes para exibir.',
      buttonText: userRole == 'profissional' ? 'Adicionar Paciente' : null,
      onButtonPressed: userRole == 'profissional'
          ? () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (context) => const AddPatientPage()),
              );
              if (result == true) _reloadData();
            }
          : null,
    );
  }

  Widget? _buildFloatingActionButton() {
    return PermissionGuard(
      permission: 'patients.create',
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          heroTag: "home_page_add_patient",
          onPressed: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (context) => const AddPatientPage()),
            );
            if (result == true) _reloadData();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.person_add_rounded, color: Colors.white),
          label: const Text(
            'Novo Paciente',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _AlertCard {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _AlertCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _QuickAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
