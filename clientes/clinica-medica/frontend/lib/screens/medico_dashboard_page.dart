// lib/screens/medico_dashboard_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:analicegrubert/models/notification_types.dart';
import 'package:analicegrubert/providers/notification_provider.dart';
import 'package:analicegrubert/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_service.dart';
import '../services/auth_service.dart';
import '../models/relatorio_medico.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/modern_widgets.dart';
import '../widgets/offline_indicator.dart';
import 'relatorio_pdf_page.dart';
import 'profile_settings_page.dart';
import 'notifications_page.dart';
import '../widgets/notification_badge.dart';
import 'package:intl/intl.dart';

class MedicoDashboardPage extends StatefulWidget {
  const MedicoDashboardPage({super.key});

  @override
  State<MedicoDashboardPage> createState() => _MedicoDashboardPageState();
}

class _MedicoDashboardPageState extends State<MedicoDashboardPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late TabController _tabController;
  
  // Variável para controlar o "ouvinte" de notificações
  late StreamSubscription<NotificationType?> _notificationSubscription;

  Future<List<RelatorioMedico>>? _relatoriosPendentes;
  Future<List<RelatorioMedico>>? _relatoriosHistorico;
  bool _isRefreshing = false;
  String _filtroHistorico = 'todos'; // 'todos', 'aprovado', 'recusado'

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupTabs();
    _loadRelatoriosPendentes();
    _loadRelatoriosHistorico();
    _setupNotificationListener();
  }
  
  void _setupNotificationListener() {
    final notificationService = NotificationService();
    _notificationSubscription = notificationService.notificationStream.listen((notificationType) {
      // Médico só precisa atualizar quando RECEBE um novo relatório para avaliar
      if (notificationType == NotificationType.novoRelatorioMedico) {
        debugPrint("✅ Novo relatório recebido, atualizando a dashboard do médico...");
        _refreshData();
      }
    });
  }

  void _refreshData() {
    if (mounted) {
      setState(() {
        _loadRelatoriosPendentes();
        _loadRelatoriosHistorico();
      });
      // CORRIGIDO: Chama o método correto do NotificationProvider
      Provider.of<NotificationProvider>(context, listen: false).loadNotifications(forceRefresh: true);
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  void _setupTabs() {
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    _notificationSubscription.cancel();
    super.dispose();
  }

  void _loadRelatoriosPendentes() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _relatoriosPendentes = apiService.getRelatoriosPendentes();
    });
  }

  void _loadRelatoriosHistorico() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    setState(() {
      String? statusFiltro = _filtroHistorico == 'todos' ? null : _filtroHistorico;
      _relatoriosHistorico = apiService.getRelatoriosMedico(status: statusFiltro);
    });
  }

  Future<void> _refreshRelatorios() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });

    await Future.delayed(const Duration(milliseconds: 300)); // UX delay
    _loadRelatoriosPendentes();
    _loadRelatoriosHistorico();

    setState(() {
      _isRefreshing = false;
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;

    return OfflineIndicator(
      child: Scaffold(
        backgroundColor: AppTheme.neutralGray50,
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              _buildModernAppBar(currentUser?.nome ?? 'Médico'),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  tabBar: _buildTabBar(),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPendentesTab(),
              _buildHistoricoTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar(String userName) {
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
          background: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildUserAvatar(),
                    const SizedBox(width: 16),
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
                            'Dr. $userName',
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
                          const StatusBadge(
                            text: 'Médico',
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
        // BOTÃO PARA CONFIGURAÇÕES DO PERFIL
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileSettingsPage()),
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

  Widget _buildUserAvatar() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileSettingsPage(),
          ),
        );
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: _buildAvatarContent(user),
        ),
      ),
    );
  }

  Widget _buildAvatarContent(user) {
    
    // Se o usuário tem foto de perfil
    if (user?.profileImage != null && user!.profileImage!.isNotEmpty) {
      
      // Se é base64
      if (user.profileImage!.startsWith('data:image')) {
        try {
          final base64String = user.profileImage!.split(',').last;
          final bytes = base64.decode(base64String);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: 64,
            height: 64,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultAvatar();
            },
          );
        } catch (e) {
          return _buildDefaultAvatar();
        }
      } 
      // Se é URL
      else {
        final imageUrl = ApiService.buildImageUrl(user.profileImage);
        if (imageUrl.isNotEmpty) {
          return Image.network(
            imageUrl,
            fit: BoxFit.cover,
            width: 64,
            height: 64,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultAvatar();
            },
          );
        } else {
           return _buildDefaultAvatar();
        }
      }
    } else {
       return _buildDefaultAvatar();
    }
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  TabBar _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: AppTheme.primaryBlue,
      unselectedLabelColor: AppTheme.neutralGray600,
      indicatorColor: AppTheme.primaryBlue,
      indicatorWeight: 3,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      tabs: const [
        Tab(
          text: 'Pendentes',
          icon: Icon(Icons.pending_actions_rounded),
          iconMargin: EdgeInsets.only(bottom: 4),
        ),
        Tab(
          text: 'Histórico',
          icon: Icon(Icons.history_rounded),
          iconMargin: EdgeInsets.only(bottom: 4),
        ),
      ],
    );
  }

  Widget _buildPendentesTab() {
    return FutureBuilder<List<RelatorioMedico>>(
      future: _relatoriosPendentes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }
        
        final relatorios = snapshot.data ?? [];
        
        if (relatorios.isEmpty) {
          return _buildEmptyState();
        }
        
        return _buildRelatoriosList(relatorios);
      },
    );
  }

  Widget _buildHistoricoTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              const Icon(
                Icons.history_rounded,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Histórico de Relatórios',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neutralGray800,
                ),
              ),
              const Spacer(),
              _buildStatusFilter(),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<RelatorioMedico>>(
            future: _relatoriosHistorico,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }
              
              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }
              
              final relatorios = snapshot.data ?? [];
              
              if (relatorios.isEmpty) {
                return _buildEmptyHistoricoState();
              }
              
              return _buildRelatoriosList(relatorios, showStatus: true);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilter() {
    return PopupMenuButton<String>(
      onSelected: (String value) {
        setState(() {
          _filtroHistorico = value;
        });
        _loadRelatoriosHistorico();
      },
      icon: const Icon(Icons.filter_list_rounded, color: AppTheme.primaryBlue),
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem(
          value: 'todos',
          child: Text('Todos'),
        ),
        const PopupMenuItem(
          value: 'aprovado',
          child: Text('Aprovados'),
        ),
        const PopupMenuItem(
          value: 'recusado',
          child: Text('Recusados'),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.errorRed,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Erro ao carregar relatórios',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: AppTheme.neutralGray600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadRelatoriosPendentes,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar Novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ModernEmptyState(
      icon: Icons.assignment_turned_in_rounded,
      title: 'Nenhum Relatório Pendente',
      subtitle: 'Parabéns! Você não tem relatórios aguardando avaliação no momento.',
      buttonText: 'Atualizar',
      onButtonPressed: _refreshRelatorios,
    );
  }

  Widget _buildEmptyHistoricoState() {
    String titulo = 'Nenhum Relatório Encontrado';
    String subtitulo = 'Não há relatórios com os filtros selecionados.';
    
    if (_filtroHistorico == 'aprovado') {
      titulo = 'Nenhum Relatório Aprovado';
      subtitulo = 'Você ainda não aprovou nenhum relatório.';
    } else if (_filtroHistorico == 'recusado') {
      titulo = 'Nenhum Relatório Recusado';
      subtitulo = 'Você ainda não recusou nenhum relatório.';
    } else {
      titulo = 'Histórico Vazio';
      subtitulo = 'Você ainda não avaliou nenhum relatório.';
    }
    
    return ModernEmptyState(
      icon: Icons.history_rounded,
      title: titulo,
      subtitle: subtitulo,
      buttonText: 'Atualizar',
      onButtonPressed: _refreshRelatorios,
    );
  }

  Widget _buildRelatoriosList(List<RelatorioMedico> relatorios, {bool showStatus = false}) {
    return RefreshIndicator(
      onRefresh: _refreshRelatorios,
      child: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: relatorios.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final relatorio = relatorios[index];
          return _buildRelatorioCard(relatorio, showStatus: showStatus);
        },
      ),
    );
  }

  Widget _buildRelatorioCard(RelatorioMedico relatorio, {bool showStatus = false}) {
    final dataLocal = relatorio.dataCriacao.toLocal();
    final dataFormatada = DateFormat('dd/MM/yyyy • HH:mm').format(dataLocal);
    
    // Configurações de status
    Color statusColor = AppTheme.warningOrange;
    String statusText = 'AGUARDANDO AVALIAÇÃO';
    IconData statusIcon = Icons.pending_actions_rounded;
    
    if (showStatus) {
      switch (relatorio.status) {
        case StatusRelatorio.aprovado:
          statusColor = AppTheme.successGreen;
          statusText = 'APROVADO';
          statusIcon = Icons.check_circle_outline_rounded;
          break;
        case StatusRelatorio.recusado:
          statusColor = AppTheme.errorRed;
          statusText = 'RECUSADO';
          statusIcon = Icons.cancel_outlined;
          break;
        case StatusRelatorio.pendente:
          statusColor = AppTheme.warningOrange;
          statusText = 'AGUARDANDO AVALIAÇÃO';
          statusIcon = Icons.pending_actions_rounded;
          break;
      }
    }
    
    return ModernCard(
      margin: EdgeInsets.zero,
      onTap: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => RelatorioPdfPage(relatorioId: relatorio.id),
          ),
        );
        
        if (result == true) {
          _loadRelatoriosPendentes();
          _loadRelatoriosHistorico();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Relatório de ${relatorio.paciente?.nome ?? 'Paciente'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.neutralGray800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Criado por: ${relatorio.criadoPor?.nome ?? 'Informação não disponível'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: relatorio.criadoPor != null
                            ? AppTheme.neutralGray600
                            : AppTheme.neutralGray400,
                        fontWeight: FontWeight.w500,
                        fontStyle: relatorio.criadoPor == null
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Criado em $dataFormatada',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.neutralGray600,
                      ),
                    ),
                    if (showStatus && relatorio.dataAvaliacao != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Avaliado em ${DateFormat('dd/MM/yyyy • HH:mm').format(relatorio.dataAvaliacao!.toLocal())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.neutralGray500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppTheme.neutralGray400,
              ),
            ],
          ),
          if (relatorio.fotos.isNotEmpty) ...[ 
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.photo_library_rounded,
                  size: 16,
                  color: AppTheme.neutralGray600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${relatorio.fotos.length} foto${relatorio.fotos.length != 1 ? 's' : ''} anexada${relatorio.fotos.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.neutralGray600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate({required this.tabBar});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.neutralGray50,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}