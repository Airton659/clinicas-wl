// lib/screens/client_dashboard.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_service.dart';
import '../models/ficha_completa.dart';
import '../models/suporte_psicologico.dart';
import '../models/exame.dart';
import '../models/medicacao.dart';
import '../models/orientacao.dart';
import '../services/auth_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/modern_widgets.dart';
import '../widgets/simple_offline_indicator.dart';
import '../widgets/notification_badge.dart';
import 'profile_settings_page.dart';
import 'notifications_page.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard>
    with TickerProviderStateMixin {
  late Future<FichaCompleta> _fichaFuture;
  late Future<List<Exame>> _examesFuture;
  late Future<List<SuportePsicologico>> _suporteFuture;
  String? userName;
  late AnimationController _headerAnimationController;
  late AnimationController _cardsAnimationController;
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _headerFadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeData();
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
    _headerAnimationController.dispose();
    _cardsAnimationController.dispose();
    super.dispose();
  }

  void _initializeData() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final userId = authService.currentUser?.id;
    userName = authService.currentUser?.nome ?? 'Paciente';

    if (userId != null) {
      _fichaFuture = apiService.getFichaCompleta(userId);
      _examesFuture = apiService.getExames(userId);
      _suporteFuture = apiService.getSuportePsicologico(userId);
    } else {
      _fichaFuture = Future.error('Usuário não autenticado');
      _examesFuture = Future.error('Usuário não autenticado');
      _suporteFuture = Future.error('Usuário não autenticado');
    }
  }

  void _reloadData() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final userId = authService.currentUser?.id;

    if (userId != null) {
      setState(() {
        _fichaFuture = apiService.getFichaCompleta(userId, forceRefresh: true);
        _examesFuture = apiService.getExames(userId, forceRefresh: true);
        _suporteFuture = apiService.getSuportePsicologico(userId, forceRefresh: true);
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    return SimpleOfflineIndicator(
      child: Scaffold(
        backgroundColor: AppTheme.neutralGray50,
        body: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: RefreshIndicator(
                onRefresh: () async {
                  _reloadData();
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    _buildExamesSection(),
                    _buildPlanoDeCuidadoSection(),
                    _buildSuportePsicologicoSection(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
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
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
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
                                userName ?? 'Paciente',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 12),
                              const StatusBadge(
                                text: 'Meu Cuidado',
                                color: Colors.white,
                                isOutlined: true,
                              ),
                              const SizedBox(height: 8),
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
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileSettingsPage(),
                ),
              );
            },
            icon: const Icon(Icons.settings_rounded, color: Colors.white),
            tooltip: 'Configurações do Perfil',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
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
              backgroundColor: Colors.white.withValues(alpha: 0.2),
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
            color: Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
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
        }
      }
    }

    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  Widget _buildExamesSection() {
    return FutureBuilder<List<Exame>>(
      future: _examesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingSection('Exames');
        }
        if (snapshot.hasError) {
          return _buildErrorSection('Exames', snapshot.error.toString());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyExamesCard();
        }

        final exames = snapshot.data!;
        final agora = DateTime.now();

        // Função auxiliar para obter DateTime completo (data + hora)
        DateTime getDataHoraCompleta(Exame exame) {
          if (exame.dataExame == null) return DateTime(1900);

          if (exame.horarioExame != null && exame.horarioExame!.isNotEmpty) {
            final parts = exame.horarioExame!.split(':');
            if (parts.length == 2) {
              final hora = int.tryParse(parts[0]) ?? 23;
              final minuto = int.tryParse(parts[1]) ?? 59;
              return DateTime(
                exame.dataExame!.year,
                exame.dataExame!.month,
                exame.dataExame!.day,
                hora,
                minuto,
              );
            }
          }
          // Se não tem horário, considera final do dia
          return DateTime(
            exame.dataExame!.year,
            exame.dataExame!.month,
            exame.dataExame!.day,
            23,
            59,
          );
        }

        // Separar em próximos e histórico
        final proximosExames = <Exame>[];
        final historicoExames = <Exame>[];

        for (final exame in exames) {
          if (exame.dataExame == null) continue;
          final dataHoraExame = getDataHoraCompleta(exame);

          if (dataHoraExame.isBefore(agora)) {
            historicoExames.add(exame);
          } else {
            proximosExames.add(exame);
          }
        }

        // Ordenar PRÓXIMOS: CRESCENTE (mais próximos/urgentes primeiro)
        proximosExames.sort((a, b) => getDataHoraCompleta(a).compareTo(getDataHoraCompleta(b)));

        // Ordenar HISTÓRICO: DECRESCENTE (mais recentes primeiro)
        historicoExames.sort((a, b) => getDataHoraCompleta(b).compareTo(getDataHoraCompleta(a)));

        return AnimatedBuilder(
          animation: _cardsAnimationController,
          builder: (context, child) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Exames', Icons.medical_services_rounded),
                  const SizedBox(height: 16),
                  _buildExamesCardWithTabs(proximosExames, historicoExames),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlanoDeCuidadoSection() {
    return FutureBuilder<FichaCompleta>(
      future: _fichaFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingSection('Plano de Cuidado');
        }
        if (snapshot.hasError) {
          return _buildErrorSection('Plano de Cuidado', snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          return _buildEmptySection('Plano de Cuidado');
        }

        final ficha = snapshot.data!;
        return AnimatedBuilder(
          animation: _cardsAnimationController,
          builder: (context, child) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Plano de Cuidado', Icons.assignment_rounded),
                  const SizedBox(height: 16),
                  if (ficha.medicacoes.isNotEmpty) ...[
                    _buildMedicacoesCard(ficha.medicacoes),
                    const SizedBox(height: 16),
                  ],
                  if (ficha.orientacoes.isNotEmpty) ...[
                    _buildOrientacoesCard(ficha.orientacoes),
                    const SizedBox(height: 16),
                  ],
                  if (ficha.medicacoes.isEmpty && ficha.orientacoes.isEmpty)
                    _buildEmptyPlanCard(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSuportePsicologicoSection() {
    return FutureBuilder<List<SuportePsicologico>>(
      future: _suporteFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingSection('Suporte Psicológico');
        }
        if (snapshot.hasError) {
          return _buildErrorSection('Suporte Psicológico', snapshot.error.toString());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptySuporteCard();
        }

        final suportes = snapshot.data!;
        return AnimatedBuilder(
          animation: _cardsAnimationController,
          builder: (context, child) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Suporte Psicológico', Icons.psychology_rounded),
                  const SizedBox(height: 16),
                  _buildSuporteCard(suportes),
                ],
              ),
            );
          },
        );
      },
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

  Widget _buildExamesCardWithTabs(List<Exame> proximosExames, List<Exame> historicoExames) {
    return DefaultTabController(
      length: 2,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: ModernCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.medical_services_outlined,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Exames Marcados',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.neutralGray800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    labelColor: AppTheme.primaryBlue,
                    unselectedLabelColor: AppTheme.neutralGray500,
                    indicatorColor: AppTheme.primaryBlue,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: [
                      Tab(text: 'Próximos (${proximosExames.length})'),
                      Tab(text: 'Histórico (${historicoExames.length})'),
                    ],
                  ),
                  SizedBox(
                    height: 300, // Altura fixa para ~3 exames
                    child: TabBarView(
                      children: [
                        _buildExamesTab(proximosExames, 'Nenhum exame agendado'),
                        _buildExamesTab(historicoExames, 'Nenhum exame no histórico'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExamesTab(List<Exame> exames, String emptyMessage) {
    if (exames.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage,
            style: TextStyle(
              color: AppTheme.neutralGray500,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: exames.length,
      separatorBuilder: (context, index) => const Divider(height: 24),
      itemBuilder: (context, index) {
        return _buildExameItem(exames[index]);
      },
    );
  }

  Widget _buildExameItem(Exame exame) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            color: AppTheme.primaryBlue,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exame.nomeExame,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutralGray800,
                ),
              ),
              if (exame.dataExame != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Data: ${DateFormat('dd/MM/yyyy').format(exame.dataExame!)}${exame.horarioExame != null ? ' às ${exame.horarioExame}' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.neutralGray600,
                  ),
                ),
              ],
              if (exame.descricao != null && exame.descricao!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.neutralGray50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.neutralGray200),
                  ),
                  child: Text(
                    exame.descricao!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.neutralGray700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (exame.urlAnexo != null && exame.urlAnexo!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.attachment_rounded,
              color: AppTheme.successGreen,
              size: 16,
            ),
          ),
      ],
    );
  }

  Widget _buildMedicacoesCard(List<Medicacao> medicacoes) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: ModernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.medication_outlined,
                        color: AppTheme.successGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Medicações',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.neutralGray800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...medicacoes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final medicacao = entry.value;
                  return Column(
                    children: [
                      if (index > 0) const Divider(height: 24),
                      _buildMedicacaoItem(medicacao),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMedicacaoItem(Medicacao medicacao) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          medicacao.nomeMedicamento,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.neutralGray800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Dosagem: ${medicacao.dosagem}',
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.neutralGray600,
          ),
        ),
        if (medicacao.instrucoes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.neutralGray50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.neutralGray200),
            ),
            child: Text(
              medicacao.instrucoes,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.neutralGray700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOrientacoesCard(List<Orientacao> orientacoes) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: ModernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        color: AppTheme.accentTeal,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Orientações',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.neutralGray800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...orientacoes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final orientacao = entry.value;
                  return Column(
                    children: [
                      if (index > 0) const Divider(height: 24),
                      _buildOrientacaoItem(orientacao),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrientacaoItem(Orientacao orientacao) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          orientacao.titulo,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.neutralGray800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.neutralGray50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.neutralGray200),
          ),
          child: Text(
            orientacao.conteudo,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.neutralGray700,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuporteCard(List<SuportePsicologico> suportes) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: ModernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recursos disponíveis para seu bem-estar psicológico',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.neutralGray600,
                  ),
                ),
                const SizedBox(height: 16),
                ...suportes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final suporte = entry.value;
                  return Column(
                    children: [
                      if (index > 0) const Divider(height: 24),
                      _buildSuporteItem(suporte),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuporteItem(SuportePsicologico suporte) {
    final isClickable = suporte.isLink && suporte.conteudo.contains('http');
    
    Widget content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: suporte.isLink 
            ? AppTheme.primaryBlue.withValues(alpha: 0.05)
            : AppTheme.neutralGray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: suporte.isLink 
              ? AppTheme.primaryBlue.withValues(alpha: 0.2)
              : AppTheme.neutralGray200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: suporte.isLink 
                  ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                  : AppTheme.neutralGray200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              suporte.isLink ? Icons.link_rounded : Icons.psychology_outlined,
              color: suporte.isLink ? AppTheme.primaryBlue : AppTheme.neutralGray600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suporte.titulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: suporte.isLink ? AppTheme.primaryBlue : AppTheme.neutralGray800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  suporte.conteudo,
                  style: TextStyle(
                    fontSize: 14,
                    color: suporte.isLink ? AppTheme.primaryBlue : AppTheme.neutralGray600,
                  ),
                  maxLines: suporte.isLink ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (suporte.isLink)
            Icon(
              isClickable ? Icons.open_in_new_rounded : Icons.link_rounded,
              color: AppTheme.primaryBlue,
              size: 16,
            ),
        ],
      ),
    );

    if (isClickable) {
      return InkWell(
        onTap: () async {
          try {
            final uri = Uri.parse(suporte.conteudo);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Não foi possível abrir o link'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erro ao abrir link: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }
    
    return content;
  }

  Widget _buildEmptyExamesCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Exames', Icons.medical_services_rounded),
          const SizedBox(height: 16),
          ModernCard(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.neutralGray100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    color: AppTheme.neutralGray500,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sem exames marcados',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.neutralGray700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Você ainda não possui exames marcados.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.neutralGray500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlanCard() {
    return ModernCard(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.neutralGray100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: AppTheme.neutralGray500,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sem plano de cuidado',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.neutralGray700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'O enfermeiro responsável ainda não criou um plano de cuidado para você.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.neutralGray500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySuporteCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Suporte Psicológico', Icons.psychology_rounded),
          const SizedBox(height: 16),
          ModernCard(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.neutralGray100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology_outlined,
                    color: AppTheme.neutralGray500,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sem recursos disponíveis',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.neutralGray700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ainda não há recursos de suporte psicológico disponíveis para você.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.neutralGray500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSection(String title) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionHeader(title, Icons.hourglass_empty_rounded),
          const SizedBox(height: 16),
          ShimmerLoading(
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection(String title, String error) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionHeader(title, Icons.error_outline_rounded),
          const SizedBox(height: 16),
          ModernEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar',
            subtitle: 'Não conseguimos carregar os dados.\nToque para tentar novamente.',
            buttonText: 'Tentar Novamente',
            onButtonPressed: _reloadData,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection(String title) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionHeader(title, Icons.info_outline_rounded),
          const SizedBox(height: 16),
          const ModernEmptyState(
            icon: Icons.info_outline_rounded,
            title: 'Sem dados',
            subtitle: 'Não há informações disponíveis no momento.',
          ),
        ],
      ),
    );
  }

}