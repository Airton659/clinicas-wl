// lib/screens/patient_details_page.dart

import 'package:analicegrubert/models/notification_types.dart';
import 'package:analicegrubert/services/notification_service.dart';
import 'package:analicegrubert/screens/edit_address_page.dart';
import 'package:analicegrubert/screens/edit_personal_data_page.dart';
import 'package:analicegrubert/widgets/anamnese_history_list.dart';
import 'package:analicegrubert/widgets/smart_support_dialog.dart';
import 'tarefas_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../utils/date_utils.dart';
import '../utils/link_detector.dart';
import '../api/api_service.dart';
import '../models/ficha_completa.dart';
import '../models/registro_diario.dart';
import '../models/checklist_item.dart';
import '../models/medicacao.dart';
import '../models/prontuario.dart';
import '../models/exame.dart';
import '../models/orientacao.dart';
import '../models/paciente.dart';
import '../models/suporte_psicologico.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/modern_widgets.dart';
import '../widgets/diary_history_filter.dart';
import '../widgets/quick_note_dialog.dart';
import '../utils/error_handler.dart';
import 'anamnese_form_page.dart';
import 'create_plan_page.dart';
import 'create_report_page.dart';
import 'patient_reports_history_page.dart';

class PatientDetailsPage extends StatefulWidget {
  final String pacienteId;
  final String? pacienteNome;
  final int? initialTabIndex;

  const PatientDetailsPage({
    super.key,
    required this.pacienteId,
    this.pacienteNome,
    this.initialTabIndex,
  });

  @override
  State<PatientDetailsPage> createState() => _PatientDetailsPageState();
}

class _PatientDetailsPageState extends State<PatientDetailsPage>
    with TickerProviderStateMixin {
  Future<FichaCompleta>? _fichaCompletaFuture;
  Future<List<RegistroDiario>>? _registrosDiarioFuture;
  Future<List<ChecklistItem>>? _dailyChecklistFuture;
  Future<Usuario?>? _patientDataFuture;
  Future<List<SuportePsicologico>>? _suportePsicologicoFuture;
  Future<List<Exame>>? _examesFuture;
  Future<List<Prontuario>>? _prontuariosFuture;
  TabController? _tabController;

  FichaCompleta? _cachedFichaCompleta;
  Usuario? _cachedPatientData;
  bool _isLoadingReadingStatus = true;
  bool _hasConfirmedReading = false;
  Map<String, dynamic>? _readingStatus;
  String? _userRole;

  List<Widget> _tabs = [];

  Future<List<Usuario>>? _tecnicosFuture;
  Usuario? _selectedTecnico;
  List<RegistroDiario> _allRegistrosCache = [];
  String? _activeDate;
  String? _activeTipo;
  bool _isFilterPanelExpanded = false;
  bool get _showHistoryFilters =>
      _userRole == 'admin' || _userRole == 'profissional';

  late AnimationController _headerAnimationController;
  late AnimationController _contentAnimationController;
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _contentFadeAnimation;

  bool _showSuccessFeedback = false;
  bool _refreshPersonalData = false;
  Timer? _successFeedbackTimer;

  // ADICIONADO: Variável para controlar o "ouvinte" de notificações
  late StreamSubscription<NotificationType?> _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePage();
      // ADICIONADO: Inicia o "ouvinte" de notificações
      _setupNotificationListener();
    });
  }

  // ADICIONADO: Método para configurar o "ouvinte" de notificações
  void _setupNotificationListener() {
    final notificationService = NotificationService();
    _notificationSubscription =
        notificationService.notificationStream.listen((notificationType) {

      // Verifica se a notificação é de plano atualizado
      if (notificationType == NotificationType.planoAtualizado) {
        debugPrint(
            "✅ Notificação de Plano de Cuidado Atualizado recebida. Verificando se é para este paciente...");
        
        // Esta é uma maneira de obter os dados da notificação. 
        // Como o stream só passa o tipo, buscamos a notificação mais recente no service.
        final latestNotification = notificationService.notifications.first;
        final notificationPatientId = latestNotification.data['paciente_id'];

        // Compara o ID do paciente da notificação com o ID do paciente desta tela
        if (notificationPatientId == widget.pacienteId) {
          debugPrint("✅ SIM! A notificação é para o paciente atual (${widget.pacienteId}). Atualizando a tela...");
          if (mounted) {
            _initializePage(forceRefresh: true);
          }
        } else {
          debugPrint("❌ NÃO. A notificação é para outro paciente ($notificationPatientId). Ignorando.");
        }
      }
    });
  }

  void _setupAnimations() {
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _headerSlideAnimation = Tween<double>(begin: -100, end: 0).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _contentFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _headerAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _contentAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _contentAnimationController.dispose();
    _tabController?.removeListener(_handleTabSelection);
    _tabController?.dispose();
    _successFeedbackTimer?.cancel();
    // ADICIONADO: Cancela a inscrição para evitar vazamento de memória
    _notificationSubscription.cancel();
    super.dispose();
  }

  Future<void> _initializePage({bool forceRefresh = false}) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    const negocioId = "rlAB6phw0EBsBFeDyOt6";

    // Super admin deve ser tratado como admin
    if (authService.currentUser?.isSuperAdmin ?? false) {
      _userRole = 'admin';
    } else {
      _userRole = authService.currentUser?.roles?[negocioId];
    }

    _setupTabs();

    setState(() {
      _fichaCompletaFuture = apiService.getFichaCompleta(widget.pacienteId, forceRefresh: forceRefresh);
      _suportePsicologicoFuture = apiService.getSuportePsicologico(widget.pacienteId, forceRefresh: forceRefresh);
      _examesFuture = apiService.getExames(widget.pacienteId, forceRefresh: forceRefresh);
      _prontuariosFuture = apiService.getProntuarios(widget.pacienteId, forceRefresh: forceRefresh);
      _patientDataFuture = apiService.getPatientById(widget.pacienteId).then((patient) {
        _cachedPatientData = patient;
        return patient;
      });

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _activeDate = today;

      if (_userRole != 'tecnico') {
        _tecnicosFuture = apiService.getTecnicosSupervisionados(widget.pacienteId);
      }

      _registrosDiarioFuture = apiService.getRegistrosDiario(widget.pacienteId, date: today, forceRefresh: forceRefresh);
      _dailyChecklistFuture = apiService.getDailyChecklist(widget.pacienteId, date: today, forceRefresh: forceRefresh);
      
      _fichaCompletaFuture?.then((_) {
        apiService.preloadRelatedData('patient_details', 
          pacienteId: widget.pacienteId, 
          userRole: _userRole
        );
      }).catchError((e) {
      });
    });

    if (_userRole == 'tecnico') {
      await _checkReadingStatus();
    } else {
      setState(() {
        _hasConfirmedReading = true;
        _isLoadingReadingStatus = false;
      });
    }
  }

  void _setupTabs() {
    _tabs = [
      _buildTab(icon: Icons.medical_services_rounded, text: 'Plano de Cuidado'),
      _buildTab(icon: Icons.task_alt_rounded, text: 'Tarefas'),
      _buildTab(icon: Icons.science_rounded, text: 'Exames'),
      _buildTabWithLock(icon: Icons.book_rounded, text: 'Diário'),
      _buildTab(icon: Icons.person_rounded, text: 'Dados'),
      _buildTab(icon: Icons.psychology_rounded, text: 'Suporte Psicológico'),
    ];

    if (_userRole == 'admin' || _userRole == 'profissional') {
      _tabs.add(_buildTab(icon: Icons.assignment_rounded, text: 'Relatórios'));
    }

    if (_userRole != 'tecnico') {
      _tabs.add(_buildTab(icon: Icons.history_edu_rounded, text: 'Avaliações'));
    }

    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTabIndex ?? 0,
    );
    _tabController!.addListener(_handleTabSelection);
  }

  void _fetchPatientData() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _patientDataFuture = apiService.getPatientById(widget.pacienteId).then((patient) {
        _cachedPatientData = patient;
        return patient;
      });
    });
  }

  void _fetchTecnicosSupervisionados() {
    if (!mounted) return;
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _tecnicosFuture = apiService.getTecnicosSupervisionados(
        widget.pacienteId,
      );
    });
  }

  Future<void> _checkReadingStatus() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final status = await apiService.getPlanReadingStatus(widget.pacienteId);
      final isConfirmed = status['leitura_confirmada'] ?? false;
      
      setState(() {
        _readingStatus = status;
        _hasConfirmedReading = isConfirmed;
        _isLoadingReadingStatus = false;
      });

      if (_hasConfirmedReading) {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        _fetchRegistrosDiario(date: today);
        _fetchDailyChecklist(date: today);
      }
    } catch (e) {
      setState(() {
        _readingStatus = {
          'leitura_confirmada': false,
          'ultima_leitura': 'Erro na verificação',
        };
        _hasConfirmedReading = false;
        _isLoadingReadingStatus = false;
      });
    }
  }

  void _refreshPatientData() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    apiService.clearCache('getFichaCompleta');
    _initializePage(forceRefresh: true);
  }

  Future<void> _confirmReading() async {
    if (_cachedFichaCompleta == null ||
        _cachedFichaCompleta!.consultas.isEmpty) {
      _showErrorSnackBar('Não há um plano de cuidado ativo para confirmar.');
      return;
    }

    setState(() => _isLoadingReadingStatus = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final String latestConsultaId = _cachedFichaCompleta!.consultas.first.id;
      final String? currentUserId = authService.currentUser?.id;

      if (currentUserId == null) {
        throw Exception("Não foi possível obter o ID do usuário logado.");
      }

      await apiService.confirmPlanReading(
        widget.pacienteId,
        latestConsultaId,
        currentUserId,
      );

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _fetchRegistrosDiario(date: today);
      _fetchDailyChecklist(date: today);

      await _checkReadingStatus();
      
      if (mounted) {
        _showSuccessSnackBar('Leitura do plano confirmada com sucesso!');
      }
    } catch (e) {
      setState(() => _isLoadingReadingStatus = false);
      if (mounted) {
        _showErrorSnackBar(ErrorHandler.getGenericErrorMessage(e));
      }
    }
  }

  void _handleTabSelection() {
    if (_userRole == 'tecnico' && !_hasConfirmedReading) {
      final currentIndex = _tabController?.index ?? 0;
      if (currentIndex != 0) {
        _tabController?.animateTo(0);
        _showWarningSnackBar('Confirme a leitura do plano antes de acessar outras seções.');
        return;
      }
    }
    
    setState(() {});
  }

  void _fetchFichaCompleta({String? consultaId}) {
    if (!mounted) return;
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _fichaCompletaFuture = apiService.getFichaCompleta(
        widget.pacienteId,
        consultaId: consultaId,
        forceRefresh: consultaId != null, // Força refresh quando vem de publicação
      );
    });
  }

  void _fetchRegistrosDiario({String? date, String? tipo}) {
    if (!mounted) return;
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _registrosDiarioFuture = apiService
          .getRegistrosDiario(widget.pacienteId, date: date, tipo: tipo)
          .then((registros) {
        if (date == null && tipo == null) {
          _allRegistrosCache = registros;
        }
        
        if (_selectedTecnico != null) {
          
          final filteredRegistros = registros.where((r) {
            return r.tecnico.id == _selectedTecnico!.id;
          }).toList();
          
          return filteredRegistros;
        }
        
        return registros;
      });
    });
  }

  void _fetchDailyChecklist({String? date}) {
    if (!mounted) return;
    final apiService = Provider.of<ApiService>(context, listen: false);

    setState(() {
      if (date != null && date.isNotEmpty) {
        _dailyChecklistFuture = apiService.getDailyChecklist(
          widget.pacienteId,
          date: date,
        );
      } else {
        _dailyChecklistFuture = Future.value([]);
      }
    });
  }

  void _onFilterChanged(String? date, String? tipo) {
    setState(() {
      _activeDate = date;
      _activeTipo = tipo;
    });

    _fetchRegistrosDiario(date: date, tipo: tipo);
    _fetchDailyChecklist(date: date);
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.warningOrange,
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null || _isLoadingReadingStatus) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Carregando...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.neutralGray50,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildModernAppBar(innerBoxIsScrolled)];
        },
        body: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: (_userRole == 'tecnico' && !_hasConfirmedReading) 
                    ? const NeverScrollableScrollPhysics() 
                    : null,
                children: <Widget>[
                  _buildPlanoCuidadoView(),
                  (_userRole == 'tecnico' && !_hasConfirmedReading)
                      ? _buildConfirmationPanel()
                      : TarefasPage(pacienteId: widget.pacienteId, pacienteNome: widget.pacienteNome ?? 'Paciente'),
                  _buildExamesView(),
                  _buildDiarioView(),
                  _buildDadosPacienteView(),
                  _buildSuportePsicologicoView(),
                  if (_userRole == 'admin' || _userRole == 'profissional') _buildRelatoriosView(),
                  if (_userRole != 'tecnico') _buildAvaliacoesView(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  // Em lib/screens/patient_details_page.dart

Widget _buildModernAppBar(bool innerBoxIsScrolled) {
  return SliverAppBar(
    expandedHeight: 200,
    floating: false,
    pinned: true,
    elevation: 0,
    backgroundColor: Colors.transparent,
    flexibleSpace: Container(
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
      child: FlexibleSpaceBar(
        title: const SizedBox.shrink(),
        background: AnimatedBuilder(
          animation: _headerAnimationController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _headerSlideAnimation.value / 2),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
                // O FutureBuilder agora constrói todo o cabeçalho
                child: FutureBuilder<Usuario?>(
                  future: _patientDataFuture,
                  builder: (context, snapshot) {
                    final patientData = snapshot.data;
                    final displayName = patientData?.nome ?? widget.pacienteNome ?? 'Paciente';
                    final displayEmail = patientData?.email ?? (snapshot.connectionState == ConnectionState.done ? 'Email não informado' : 'Carregando...');
                    // USA O CAMPO CORRETO: profileImage
                    final imageUrl = patientData?.profileImage;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Avatar agora recebe a URL da imagem
                            ModernAvatar(
                              name: displayName,
                              imageUrl: imageUrl, // Passa a URL para o avatar
                              radius: 32,
                              hasGradient: false,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    displayEmail,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    ),
    leading: Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutralGray200),
        boxShadow: [
          BoxShadow(
            color: AppTheme.neutralGray200.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.neutralGray600,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: _tabs,
      ),
    );
  }

  Widget _buildTab({required IconData icon, required String text}) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildTabWithLock({required IconData icon, required String text}) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildPlanoCuidadoView() {
    return FadeTransition(
      opacity: _contentFadeAnimation,
      child: Column(
        children: [
          Expanded(
            child: FutureBuilder<FichaCompleta>(
              future: _fichaCompletaFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }
                if (snapshot.hasError) {
                  return _buildErrorState(
                    'Erro ao carregar plano de cuidados. Tente novamente.',
                  );
                }
                if (!snapshot.hasData) {
                  return _buildEmptyPlanState();
                }

                _cachedFichaCompleta = snapshot.data;
                final ficha = snapshot.data!;

                debugPrint('🔍 PRONTUÁRIO DEBUG - Total: ${ficha.prontuarios.length}');
                for (int i = 0; i < ficha.prontuarios.length; i++) {
                  final p = ficha.prontuarios[i];
                  debugPrint('📝 Prontuário $i: ${p.titulo} - ${p.conteudo.substring(0, p.conteudo.length < 50 ? p.conteudo.length : 50)}...');
                }

                return RefreshIndicator(
                  onRefresh: () async => _fetchFichaCompleta(),
                  child: _buildPlanContent(ficha),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanContent(FichaCompleta ficha) {
    bool hasPlanContent = ficha.orientacoes.isNotEmpty ||
        ficha.checklist.isNotEmpty ||
        ficha.medicacoes.isNotEmpty; 
        
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        if (ficha.orientacoes.isNotEmpty) ...[
          _buildSectionHeader(
            'Orientações e Metas',
            Icons.psychology_rounded,
            AppTheme.primaryBlue,
          ),
          ...ficha.orientacoes.map((o) => _buildOrientacaoCard(o)).toList(),
          const SizedBox(height: 24),
        ],
        if (ficha.checklist.isNotEmpty) ...[
          _buildSectionHeader(
            'Checklist Modelo',
            Icons.checklist_rounded,
            AppTheme.accentTeal,
          ),
          ...ficha.checklist.map((c) => _buildChecklistCard(c)).toList(),
          const SizedBox(height: 24),
        ],
        if (ficha.medicacoes.isNotEmpty) ...[
          _buildSectionHeader(
            'Medicações',
            Icons.medication_rounded,
            AppTheme.errorRed,
          ),
          ...ficha.medicacoes.map((m) => _buildMedicacaoCard(m)).toList(),
          const SizedBox(height: 24),
        ],
        if (!hasPlanContent) _buildEmptyPlanState(),
        
        if (_userRole == 'tecnico' && !_hasConfirmedReading)
          _buildConfirmationPanel(),
        
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildExamesView() {
    if (_userRole == 'tecnico' && !_hasConfirmedReading) {
      return _buildConfirmationPanel();
    }

    return FadeTransition(
      opacity: _contentFadeAnimation,
      child: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Exame>>(
              future: _examesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }
                if (snapshot.hasError) {
                  return _buildErrorState(
                    'Erro ao carregar exames. Tente novamente.',
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyExamesState();
                }

                return _buildExamesContent(snapshot.data!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDadosPacienteView() {
    if (_userRole == 'tecnico' && !_hasConfirmedReading) {
      return _buildConfirmationPanel();
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildPatientInfoCard(),
        _buildPersonalDataCard(),
        _buildAddressCard(),
      ],
    );
  }

  Widget _buildSuportePsicologicoView() {
    if (_userRole == 'tecnico' && !_hasConfirmedReading) {
      return _buildConfirmationPanel();
    }

    return FutureBuilder<List<SuportePsicologico>>(
      future: _suportePsicologicoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        }
        
        final suportes = snapshot.data ?? [];
        
        if (suportes.isEmpty) {
          return _buildEmptySuportePsicologico();
        }
        
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionHeader(
              'Recursos de Suporte Psicológico',
              Icons.psychology_rounded,
              AppTheme.successGreen,
            ),
            ...suportes.map((suporte) => _buildSuportePsicologicoCard(suporte)),
          ],
        );
      },
    );
  }

  Widget _buildRelatoriosView() {
    return PatientReportsHistoryPage(
      pacienteId: widget.pacienteId,
      pacienteNome: widget.pacienteNome ?? 'Paciente',
      showFloatingActionButton: false,
    );
  }

  Widget _buildAvaliacoesView() {
    return AnamneseHistoryList(
      pacienteId: widget.pacienteId, 
      pacienteNome: widget.pacienteNome ?? 'Paciente',
    );
  }

  Widget _buildPatientInfoCard() {
    return FutureBuilder<Usuario?>(
      future: _patientDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ModernCard(child: LinearProgressIndicator());
        }

        final patient = snapshot.data;
        
        return ModernCard(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_pin_rounded, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  const Text('Informações de Contato', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 24),
              _buildInfoRow('Email', patient?.email ?? 'Não informado'),
              const SizedBox(height: 8),
              _buildInfoRow('Telefone', patient?.telefone ?? 'Não informado'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddressCard() {
    return FutureBuilder<Usuario?>(
      future: _patientDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ModernCard(child: LinearProgressIndicator());
        }

        final address = snapshot.data?.endereco;
        final hasAddress = address != null && address.isNotEmpty;

        return ModernCard(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  const Text('Endereço', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_userRole == 'admin' || _userRole == 'profissional')
                    IconButton(
                      icon: Icon(hasAddress ? Icons.edit_rounded : Icons.add_rounded, color: AppTheme.primaryBlue),
                      tooltip: hasAddress ? 'Editar Endereço' : 'Adicionar Endereço',
                      onPressed: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditAddressPage(
                              pacienteId: widget.pacienteId,
                              initialAddress: hasAddress ? address : null,
                            ),
                          ),
                        );
                        if (result == true) {
                          _fetchPatientData();
                        }
                      },
                    ),
                ],
              ),
              if (hasAddress) ...[
                const Divider(height: 16),
                Text('${address['rua']}, ${address['numero']}', style: const TextStyle(fontSize: 14)),
                if (address['bairro'] != null && address['bairro'].isNotEmpty)
                  Text('${address['bairro']}', style: const TextStyle(fontSize: 14)),
                Text('${address['cidade']}, ${address['estado']}', style: const TextStyle(fontSize: 14)),
                Text('CEP: ${address['cep']}', style: const TextStyle(fontSize: 14)),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text("Nenhum endereço cadastrado.", style: TextStyle(color: AppTheme.neutralGray500)),
                ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildDiarioView() {
    return FadeTransition(
      opacity: _contentFadeAnimation,
      child: () {
        if (_userRole == 'tecnico') {
          if (!_hasConfirmedReading) {
            return _buildConfirmationPanel();
          }
          return _buildTecnicoDiarioView();
        }

        return _buildProntuariosView();
      }(),
    );
  }

  Widget _buildProntuariosView() {
    return FutureBuilder<List<Prontuario>>(
      future: _prontuariosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Erro ao carregar prontuários:\n${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _prontuariosFuture = Provider.of<ApiService>(context, listen: false).getProntuarios(widget.pacienteId, forceRefresh: true);
                    });
                  },
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }

        final prontuarios = snapshot.data ?? [];

        if (prontuarios.isEmpty) {
          return ModernEmptyState(
            icon: Icons.description,
            title: 'Diário Vazio',
            subtitle: _userRole == 'tecnico'
                ? 'Você ainda não fez registros no diário.\nComece adicionando uma nova entrada!'
                : 'Não há registros no diário para este paciente.',
            buttonText: (_userRole == 'tecnico' && _hasConfirmedReading) ? 'Novo Prontuário' : null,
            onButtonPressed: (_userRole == 'tecnico' && _hasConfirmedReading) ? _openProntuarios : null,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            final future = Provider.of<ApiService>(context, listen: false).getProntuarios(widget.pacienteId, forceRefresh: true);
            setState(() {
              _prontuariosFuture = future;
            });
            await future;
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: prontuarios.length,
            itemBuilder: (context, index) {
              final prontuario = prontuarios[index];
              return _buildProntuarioCard(prontuario);
            },
          ),
        );
      },
    );
  }

  Widget _buildProntuarioCard(Prontuario prontuario) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return ModernCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description, color: AppTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  prontuario.tecnicoNome ?? 'Prontuário',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                dateFormat.format(prontuario.data),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            prontuario.texto,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTecnicoDiarioView() {
    return Column(
      children: [
        _buildDailyChecklistSection(),
        const Divider(height: 1),
        Expanded(child: _buildProntuariosView()),
      ],
    );
  }

  Widget _buildTecnicoSelectionView() {
    return FutureBuilder<List<Usuario>>(
      future: _tecnicosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        if (snapshot.hasError) {
          return _buildErrorState('Erro ao carregar equipe. Tente atualizar a página.');
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return ModernEmptyState(
            icon: Icons.people_outline,
            title: 'Nenhum Técnico Vinculado',
            subtitle: 'Não há técnicos associados a este paciente.',
          );
        }

        final tecnicos = snapshot.data!;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildSectionHeader(
                'Supervisão da Equipe',
                Icons.supervisor_account_rounded,
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tecnicos.length,
                itemBuilder: (context, index) {
                  final tecnico = tecnicos[index];
                  return ModernCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    onTap: () {
                      setState(() {
                        _selectedTecnico = tecnico;
                        final currentDate = _activeDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
                        _fetchRegistrosDiario(date: currentDate);
                        _fetchDailyChecklist(date: currentDate);
                      });
                    },
                    child: Row(
                      children: [
                        ModernAvatar(name: tecnico.nome, radius: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tecnico.nome ?? 'Técnico',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                tecnico.email ?? 'Sem email',
                                style: const TextStyle(
                                  color: AppTheme.neutralGray500,
                                  fontSize: 12,
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
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSupervisorFilteredDiarioView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    setState(() {
                      _selectedTecnico = null;
                      _activeDate =
                          DateFormat('yyyy-MM-dd').format(DateTime.now());
                      _activeTipo = null;
                      _isFilterPanelExpanded = true;
                      _fetchRegistrosDiario(date: _activeDate);
                      _fetchDailyChecklist(date: _activeDate);
                    });
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Analisando Diário de:',
                        style: TextStyle(
                          color: AppTheme.neutralGray500,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _selectedTecnico?.nome ?? 'Técnico',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.neutralGray800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildFilterExpansionPanel(),
          _buildDailyChecklistSection(),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: _buildDiarioTimeline(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterExpansionPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.neutralGray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neutralGray200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isFilterPanelExpanded = !_isFilterPanelExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    color: AppTheme.primaryBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getFilterSummary(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(
                    _isFilterPanelExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: DiaryHistoryFilter(
                onFilterChanged: _onFilterChanged,
                initialDate: _activeDate,
                initialTipo: _activeTipo,
              ),
            ),
            secondChild: Container(),
            crossFadeState: _isFilterPanelExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  String _getFilterSummary() {
    final dateText = _activeDate != null 
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(_activeDate!))
        : 'Hoje';
    
    final typeText = _activeTipo?.isNotEmpty == true 
        ? ' • ${_getTipoDisplayNameFromString(_activeTipo!)}'
        : '';
    
    return 'Filtros: $dateText$typeText';
  }

  String _getTipoDisplayNameFromString(String tipo) {
    switch (tipo) {
      case 'sinais_vitais': return 'Sinais Vitais';
      case 'medicacao': return 'Medicações';
      case 'intercorrencia': return 'Intercorrências';
      case 'atividade': return 'Atividades';
      case 'anotacao': return 'Anotações';
      default: return 'Todos';
    }
  }

  Widget _buildDiarioTimeline() {
    return FutureBuilder<List<RegistroDiario>>(
      future: _registrosDiarioFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        if (snapshot.hasError) {
          return _buildErrorState('Erro ao carregar diário. Tente atualizar a página.');
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyDiaryState();
        }

        final registros = snapshot.data!;
        final authService = Provider.of<AuthService>(context, listen: false);
        const negocioId = "rlAB6phw0EBsBFeDyOt6";
        final canEdit = authService.currentUser?.roles?[negocioId] == 'tecnico';

        return RefreshIndicator(
          onRefresh: () async {
            final dateToRefresh = _activeDate;
            _fetchRegistrosDiario(date: dateToRefresh, tipo: _activeTipo);
            _fetchDailyChecklist(date: dateToRefresh);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            itemCount: registros.length,
            itemBuilder: (context, index) {
              final registro = registros[index];
              return _buildDiaryCard(registro, index, canEdit);
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, [Color? color]) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (color ?? AppTheme.primaryBlue).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color ?? AppTheme.primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color ?? AppTheme.neutralGray800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrientacaoCard(Orientacao orientacao) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: AppTheme.primaryBlue,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  orientacao.titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.neutralGray800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            orientacao.conteudo,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.neutralGray600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuportePsicologicoCard(SuportePsicologico suporte) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  suporte.isLink ? Icons.link_rounded : Icons.psychology_rounded,
                  color: AppTheme.successGreen,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  suporte.titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.neutralGray800,
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final currentUserId = authService.currentUser?.firebaseUid;
                  final isCreator = currentUserId != null && currentUserId == suporte.criadoPor;
                  final isAdmin = _userRole == 'admin';
                  final canEdit = isAdmin || isCreator;
                  
                  if (!canEdit) return const SizedBox.shrink();
                  
                  return PopupMenuButton<String>(
                    onSelected: (value) => _handleSuporteAction(value, suporte),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_rounded),
                          title: Text('Editar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_rounded, color: Colors.red),
                          title: Text('Excluir', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (suporte.isLink) ...[
            InkWell(
              onTap: () => _openLink(suporte.conteudo),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.successGreen.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 16, color: AppTheme.successGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        suporte.conteudo,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.successGreen,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Text(
              suporte.conteudo,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.neutralGray600,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptySuportePsicologico() {
    return ModernEmptyState(
      icon: Icons.psychology_rounded,
      title: 'Nenhum Recurso Adicionado',
      subtitle: 'Ainda não há recursos de suporte psicológico cadastrados para este paciente.',
      buttonText: 'Adicionar Recurso',
      onButtonPressed: () => _showAddSuportePsicologicoDialog(),
    );
  }

  Widget _buildChecklistCard(ChecklistItem item) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            item.concluido
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
            color: item.concluido
                ? AppTheme.successGreen
                : AppTheme.neutralGray400,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              item.descricaoItem,
              style: TextStyle(
                fontSize: 14,
                color: item.concluido
                    ? AppTheme.neutralGray600
                    : AppTheme.neutralGray800,
                decoration: item.concluido ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProntuariosSection() {
    return FutureBuilder<List<Prontuario>>(
      future: _prontuariosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 50,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          debugPrint('❌ Erro ao carregar prontuários: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        final prontuarios = snapshot.data ?? [];

        debugPrint('🔍 PRONTUÁRIOS NOVO ENDPOINT - Total: ${prontuarios.length}');
        for (int i = 0; i < prontuarios.length; i++) {
          final p = prontuarios[i];
          debugPrint('📝 Prontuário $i: ${p.titulo} - ${p.conteudo.substring(0, p.conteudo.length < 50 ? p.conteudo.length : 50)}...');
        }

        if (prontuarios.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            _buildSectionHeader(
              'Prontuários',
              Icons.description_rounded,
              AppTheme.warningOrange,
            ),
            ...prontuarios.map((p) => _buildProntuarioCard(p)).toList(),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildMedicacaoCard(Medicacao medicacao) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: AppTheme.errorRed,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  medicacao.nomeMedicamento,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.neutralGray800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Dosagem', medicacao.dosagem),
          const SizedBox(height: 8),
          _buildInfoRow('Instruções', medicacao.instrucoes),
        ],
      ),
    );
  }

  Widget _buildExameCard(Exame exame) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.science_rounded,
                  color: AppTheme.successGreen,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  exame.nomeExame,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.neutralGray800,
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  if (_userRole != 'admin' && _userRole != 'profissional') {
                    return const SizedBox.shrink();
                  }
                  
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final currentUserId = authService.currentUser?.firebaseUid;
                  final isCreator = currentUserId != null && 
                                   exame.criadoPor != null && 
                                   currentUserId == exame.criadoPor;
                  final isAdmin = _userRole == 'admin';
                  final canEdit = isAdmin || (exame.criadoPor != null && isCreator);
                  
                  if (!canEdit) return const SizedBox.shrink();
                  
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        color: AppTheme.primaryBlue,
                        onPressed: () => _showEditExameDialog(exame),
                        tooltip: 'Editar exame',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, size: 20),
                        color: AppTheme.errorRed,
                        onPressed: () => _showDeleteExameDialog(exame),
                        tooltip: 'Deletar exame',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Data',
            exame.dataExame != null
                ? DateFormat('dd/MM/yyyy').format(exame.dataExame!)
                : 'Não informada',
          ),
          if (exame.horarioExame != null && exame.horarioExame!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Horário', exame.horarioExame!),
          ],
          if (exame.descricao != null && exame.descricao!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Descrição', exame.descricao!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.neutralGray500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.neutralGray700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ModernCard(
        hasGradient: true,
        gradientColors: [AppTheme.warningOrange.withOpacity(0.1), Colors.white],
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.warningOrange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confirmação de Leitura Necessária',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.neutralGray800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Para acessar o diário, confirme a leitura do plano.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.neutralGray600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_readingStatus != null) ...[
              const SizedBox(height: 12),
              Text(
                'Última leitura: ${_readingStatus!['ultima_leitura'] ?? 'Nunca'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.neutralGray500,
                ),
              ),
            ],
            const SizedBox(height: 16),
            GradientButton(
              text: 'Confirmar Leitura do Plano',
              onPressed: _confirmReading,
              isLoading: _isLoadingReadingStatus,
              icon: Icons.check_circle_outline_rounded,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyChecklistSection() {
    return FutureBuilder<List<ChecklistItem>>(
      future: _dailyChecklistFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: LinearProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          if (_userRole != 'tecnico' && _selectedTecnico != null) {
            final displayDate = _activeDate != null
                ? DateFormat("dd/MM/yyyy").format(DateTime.parse(_activeDate!))
                : "hoje";
            return Container(
              margin: const EdgeInsets.all(16),
              child: ModernCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.neutralGray500,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Não há checklist registrado para ${_selectedTecnico!.nome} em $displayDate.',
                          style: const TextStyle(
                            color: AppTheme.neutralGray600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }

        final items = snapshot.data!;
        final displayDate = _activeDate != null
            ? DateFormat("dd/MM/yyyy").format(DateTime.parse(_activeDate!))
            : "Hoje";

        return Container(
          margin: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxHeight: 400),
          child: ModernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.checklist_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Checklist de $displayDate',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.neutralGray800,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: items.map((item) => _buildDailyChecklistItem(item)).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyChecklistItem(ChecklistItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        title: Text(
          item.descricaoItem,
          style: TextStyle(
            fontSize: 14,
            color: item.concluido
                ? AppTheme.neutralGray600
                : AppTheme.neutralGray800,
            decoration: item.concluido ? TextDecoration.lineThrough : null,
          ),
        ),
        value: item.concluido,
        onChanged: (_userRole == 'tecnico' && !item.concluido)
            ? (bool? value) => _toggleChecklistItem(item.id, value ?? false)
            : null,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppTheme.successGreen,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  IconData _getTipoIcon(TipoRegistro tipo) {
    switch (tipo) {
      case TipoRegistro.medicacao:
        return Icons.medication_rounded;
      case TipoRegistro.atividade:
        return Icons.event_available_rounded;
      case TipoRegistro.intercorrencia:
        return Icons.report_problem_rounded;
      case TipoRegistro.sinaisVitais:
        return Icons.favorite_rounded;
      case TipoRegistro.anamnese:
        return Icons.description_rounded;
      default:
        return Icons.note_alt_rounded;
    }
  }

  Widget _buildDiaryCard(RegistroDiario registro, int index, bool canEdit) {
    final tipo = registro.tipo;
    final color = _getTipoColor(tipo);
    final icon = _getTipoIcon(tipo);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(30 * (1 - value), 0),
          child: Opacity(
            opacity: value,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: 96,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                Expanded(
                  child: ModernCard(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(icon, color: color, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _getTipoDisplayName(tipo),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.neutralGray800,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('HH:mm').format(
                                          registro.dataHora.toLocal(),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.neutralGray500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (registro.tecnico.nome?.isNotEmpty ?? false)
                                        ? registro.tecnico.nome!
                                        : 'Técnico',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.neutralGray600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (registro.anotacoes != null &&
                            registro.anotacoes!.isNotEmpty)
                          Text(
                            registro.anotacoes!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.neutralGray700,
                              height: 1.4,
                            ),
                          )
                        else
                          Text(
                            'Registro estruturado antigo (sem descrição).',
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: AppTheme.neutralGray500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getTipoDisplayName(TipoRegistro tipo) {
    switch (tipo) {
      case TipoRegistro.medicacao:
        return 'Medicação';
      case TipoRegistro.atividade:
        return 'Atividade';
      case TipoRegistro.intercorrencia:
        return 'Intercorrência';
      case TipoRegistro.sinaisVitais:
        return 'Sinais Vitais';
      case TipoRegistro.anamnese:
        return 'Anamnese';
      default:
        return "Prontuário";
    }
  }

  Color _getTipoColor(TipoRegistro tipo) {
    switch (tipo) {
      case TipoRegistro.medicacao:
        return AppTheme.errorRed;
      case TipoRegistro.atividade:
        return AppTheme.successGreen;
      case TipoRegistro.intercorrencia:
        return AppTheme.warningOrange;
      case TipoRegistro.sinaisVitais:
        return AppTheme.primaryBlue;
      case TipoRegistro.anamnese:
        return Colors.purple.shade400;
      default:
        return AppTheme.neutralGray500;
    }
  }

  Future<void> _toggleChecklistItem(String itemId, bool isCompleted) async {
    if (isCompleted) {
      final confirmed = await _showChecklistConfirmationDialog();
      if (!confirmed) return;
    }

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      await apiService.updateChecklistItem(widget.pacienteId, itemId,
          isCompleted,
          date: _activeDate);
      _fetchDailyChecklist(date: _activeDate);
      _fetchFichaCompleta();

      if (mounted) {
        _showSuccessSnackBar(
          isCompleted ? 'Tarefa marcada como concluída!' : 'Tarefa desmarcada!',
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(ErrorHandler.getGenericErrorMessage(e));
      }
    }
  }

  Future<bool> _showChecklistConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.warningOrange,
                  ),
                  SizedBox(width: 8),
                  Text('Confirmação'),
                ],
              ),
              content: const Text(
                'Ao marcar esta tarefa como concluída, a ação será definitiva e não poderá ser desfeita.\n\nDeseja continuar?',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                GradientButton(
                  text: 'Confirmar',
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Carregando...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return ModernEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Erro ao Carregar',
      subtitle: message,
      buttonText: 'Tentar Novamente',
      onButtonPressed: () {
        _fetchFichaCompleta();
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        _fetchRegistrosDiario(date: today);
        _fetchDailyChecklist(date: today);
      },
    );
  }

  Widget _buildEmptyPlanState() {
    return ModernEmptyState(
      icon: Icons.medical_services_outlined,
      title: 'Nenhum Plano Encontrado',
      subtitle: 'Este paciente ainda não possui um plano de cuidado ativo.',
      buttonText: (_userRole == 'admin' || _userRole == 'profissional')
          ? 'Criar Plano'
          : null,
      onButtonPressed: (_userRole == 'admin' || _userRole == 'profissional')
          ? () async {
              final consultaId = await Navigator.push<String?>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CreatePlanPage(pacienteId: widget.pacienteId),
                ),
              );
              if (consultaId != null) {
                _fetchFichaCompleta(consultaId: consultaId);
              }
            }
          : null,
    );
  }

  Widget _buildEmptyDiaryState() {
    if (_userRole != 'tecnico' && _selectedTecnico != null) {
      final displayDate = _activeDate != null
          ? DateFormat("dd/MM/yyyy").format(DateTime.parse(_activeDate!))
          : "hoje";
      return ModernEmptyState(
        icon: Icons.book_outlined,
        title: 'Sem Registros',
        subtitle: 'Não há registros no diário de ${_selectedTecnico!.nome} para $displayDate.',
      );
    }
    
    return ModernEmptyState(
      icon: Icons.book_outlined,
      title: 'Diário Vazio',
      subtitle: _userRole == 'tecnico'
          ? 'Você ainda não fez registros no diário.\nComece adicionando uma nova entrada!'
          : 'Não há registros no diário para este paciente.',
      buttonText: _userRole == 'tecnico' ? 'Novo Prontuário' : null,
      onButtonPressed: _userRole == 'tecnico' ? _openProntuarios : null,
    );
  }

  Future<void> _openProntuarios() async {
    final diarioTabIndex = 3;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreateProntuarioDialog(
        pacienteId: widget.pacienteId,
        pacienteNome: widget.pacienteNome ?? 'Paciente',
      ),
    );

    if (result == true && mounted) {
      _initializePage(forceRefresh: true);

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_tabController != null && mounted) {
          _tabController!.animateTo(diarioTabIndex);
        }
      });
    }
  }

  void _showQuickNoteDialog({
    TipoRegistro tipo = TipoRegistro.anotacao,
    RegistroDiario? registro,
  }) async {

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => QuickNoteDialog(
        pacienteId: widget.pacienteId,
        tipoRegistro: tipo,
        initialValue: registro,
        onSubmit: (data) async {
          final apiService = Provider.of<ApiService>(context, listen: false);
          try {
            if (registro != null) {
              await apiService.updateRegistroDiario(
                widget.pacienteId,
                registro.id,
                data,
              );
            } else {
              await apiService.createRegistroDiario(widget.pacienteId, data);
            }

            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
            _fetchRegistrosDiario(date: today);

            if (mounted) {
              Navigator.of(context).pop(true);
            }
          } catch (e) {
            if (mounted) {
              Navigator.of(context).pop(false);
            }
            rethrow;
          }
        },
      ),
    );

    if (mounted && result != null) {
      if (result) {
        setState(() => _showSuccessFeedback = true);
        _successFeedbackTimer?.cancel();
        _successFeedbackTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _showSuccessFeedback = false);
          }
        });
      } else {
        _showErrorSnackBar('Erro ao salvar registro');
      }
    }
  }

  void _handleSuporteAction(String action, SuportePsicologico suporte) {
    switch (action) {
      case 'edit':
        _showEditSuportePsicologicoDialog(suporte);
        break;
      case 'delete':
        _showDeleteSuporteDialog(suporte);
        break;
    }
  }

  Future<void> _openLink(String url) async {
    try {
      String normalizedUrl = url.trim();

      if (!normalizedUrl.startsWith('http://') && !normalizedUrl.startsWith('https://')) {
        normalizedUrl = 'http://$normalizedUrl';
      }

      final uri = Uri.parse(normalizedUrl);

      if (!uri.hasScheme || !uri.hasAuthority) {
        throw Exception('URL inválida: $normalizedUrl');
      }

      bool success = false;

      if (await canLaunchUrl(uri)) {
        try {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
          success = true;
        } catch (e) {
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            success = true;
          } catch (e2) {
            await launchUrl(uri, mode: LaunchMode.inAppWebView);
            success = true;
          }
        }
      }

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Não foi possível abrir o link: $normalizedUrl\nVerifique se você tem um navegador instalado.'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir link: ${e.toString()}\nURL original: $url'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showAddSuportePsicologicoDialog() {
    _showSuportePsicologicoDialog();
  }

  void _showEditSuportePsicologicoDialog(SuportePsicologico suporte) {
    _showSuportePsicologicoDialog(suporte: suporte);
  }

  void _showSuportePsicologicoDialog({SuportePsicologico? suporte}) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return SmartSupportDialog(
          suporte: suporte,
          onSubmit: (titulo, conteudo, tipo) {
            _submitSuportePsicologico(titulo, conteudo, tipo, suporte);
          },
        );
      },
    );
  }

  void _submitSuportePsicologico(
    String titulo,
    String conteudo,
    String tipo,
    SuportePsicologico? suporte,
  ) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final isEditing = suporte != null;

    try {
      final data = {
        'titulo': titulo,
        'conteudo': conteudo,
        'tipo': tipo,
      };

      if (isEditing) {
        await apiService.updateSuportePsicologico(widget.pacienteId, suporte.id, data);
      } else {
        await apiService.createSuportePsicologico(widget.pacienteId, data);
      }

      if (mounted) {
        Navigator.of(context).pop();
        _showSuccessSnackBar('Recurso ${isEditing ? 'atualizado' : 'adicionado'} com sucesso!');

        setState(() {
          _suportePsicologicoFuture = apiService.getSuportePsicologico(widget.pacienteId, forceRefresh: true);
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao ${isEditing ? 'atualizar' : 'adicionar'} recurso: $e');
      }
    }
  }

  void _showDeleteSuporteDialog(SuportePsicologico suporte) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: Text('Deseja realmente excluir o recurso "${suporte.titulo}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => _deleteSuportePsicologico(context, suporte),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Excluir', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _deleteSuportePsicologico(BuildContext context, SuportePsicologico suporte) async {
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      await apiService.deleteSuportePsicologico(widget.pacienteId, suporte.id);

      if (mounted) {
        Navigator.of(context).pop();
        _showSuccessSnackBar('Recurso excluído com sucesso!');
        
        setState(() {
          _suportePsicologicoFuture = apiService.getSuportePsicologico(widget.pacienteId, forceRefresh: true);
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showErrorSnackBar('Erro ao excluir recurso: $e');
      }
    }
  }

  Widget _buildEmptyExamesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.neutralGray100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.science_outlined,
              color: AppTheme.neutralGray500,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhum exame marcado',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.neutralGray700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Adicione exames para este paciente usando o botão abaixo.',
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

  Widget _buildExamesContent(List<Exame> exames) {
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

    return Column(
      children: [
        _buildSectionHeader(
          'Exames Marcados',
          Icons.science_rounded,
          AppTheme.successGreen,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  labelColor: AppTheme.successGreen,
                  unselectedLabelColor: AppTheme.neutralGray500,
                  indicatorColor: AppTheme.successGreen,
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
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildExamesTabView(proximosExames, 'Nenhum exame agendado'),
                      _buildExamesTabView(historicoExames, 'Nenhum exame no histórico'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExamesTabView(List<Exame> exames, String emptyMessage) {
    if (exames.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage,
            style: const TextStyle(
              color: AppTheme.neutralGray500,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: exames.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildExameCard(exames[index]),
        );
      },
    );
  }

  void _showAddExameDialog() {
    final nomeController = TextEditingController();
    final descricaoController = TextEditingController();
    final dataController = TextEditingController();
    final horarioController = TextEditingController();
    DateTime? selectedDate;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.science_rounded, color: AppTheme.successGreen),
              ),
              const SizedBox(width: 12),
              const Text('Adicionar Exame'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Exame*',
                    hintText: 'Ex: Hemograma completo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dataController,
                  decoration: const InputDecoration(
                    labelText: 'Data*',
                    hintText: 'DD/MM/AAAA',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      selectedDate = date;
                      dataController.text = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: horarioController,
                  decoration: const InputDecoration(
                    labelText: 'Horário',
                    hintText: 'HH:MM',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time_rounded),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      horarioController.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descricaoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descrição/Observações',
                    hintText: 'Instruções especiais, preparação necessária, etc.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => _createExame(
                nomeController.text,
                selectedDate,
                horarioController.text,
                descricaoController.text,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createExame(String nome, DateTime? data, String horario, String descricao) async {
    if (nome.trim().isEmpty) {
      _showErrorSnackBar('Nome do exame é obrigatório');
      return;
    }
    if (data == null) {
      _showErrorSnackBar('Data do exame é obrigatória');
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final negocioId = await authService.getNegocioId();
      
      final exameData = {
        'nome_exame': nome.trim(),
        'data_exame': data.toIso8601String(),
        'paciente_id': widget.pacienteId,
        'negocio_id': negocioId,
        'horario_exame': horario.trim().isEmpty ? null : horario.trim(),
        'descricao': descricao.trim().isEmpty ? null : descricao.trim(),
      };

      exameData.removeWhere((key, value) => value == null);

      await apiService.createExame(widget.pacienteId, exameData);
      
      if (mounted) {
        Navigator.of(context).pop();
        _showSuccessSnackBar('Exame adicionado com sucesso!');
        
        setState(() {
          _examesFuture = apiService.getExames(widget.pacienteId, forceRefresh: true);
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao adicionar exame: $e');
      }
    }
  }

  void _showEditExameDialog(Exame exame) {
    final nomeController = TextEditingController(text: exame.nomeExame);
    final horarioController = TextEditingController(text: exame.horarioExame ?? '');
    final descricaoController = TextEditingController(text: exame.descricao ?? '');
    DateTime? selectedDate = exame.dataExame;
    TimeOfDay? selectedTime = exame.horarioExame != null 
        ? TimeOfDay(
            hour: int.tryParse(exame.horarioExame!.split(':')[0]) ?? 0,
            minute: int.tryParse(exame.horarioExame!.split(':')[1]) ?? 0,
          )
        : null;

    showDialog(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit_rounded, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              const Text('Editar Exame'),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Exame *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setStateDialog(() => selectedDate = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data do Exame *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      selectedDate != null
                          ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                          : 'Selecione a data',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      setStateDialog(() {
                        selectedTime = time;
                        horarioController.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Horário',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(
                      horarioController.text.isEmpty 
                          ? 'Selecione o horário' 
                          : horarioController.text,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descricaoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descrição/Instruções',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => _updateExame(
                exame.id,
                nomeController.text,
                selectedDate,
                horarioController.text,
                descricaoController.text,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteExameDialog(Exame exame) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppTheme.errorRed),
            const SizedBox(width: 8),
            const Text('Confirmar Exclusão'),
          ],
        ),
        content: Text('Tem certeza de que deseja excluir o exame "${exame.nomeExame}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => _deleteExame(exame.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateExame(String exameId, String nome, DateTime? data, String horario, String descricao) async {
    if (nome.trim().isEmpty) {
      _showErrorSnackBar('Nome do exame é obrigatório');
      return;
    }
    if (data == null) {
      _showErrorSnackBar('Data do exame é obrigatória');
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final negocioId = await authService.getNegocioId();
      
      final exameData = {
        'nome_exame': nome.trim(),
        'data_exame': data.toIso8601String(),
        'paciente_id': widget.pacienteId,
        'negocio_id': negocioId,
        'horario_exame': horario.trim().isEmpty ? null : horario.trim(),
        'descricao': descricao.trim().isEmpty ? null : descricao.trim(),
      };

      exameData.removeWhere((key, value) => value == null);

      await apiService.updateExame(widget.pacienteId, exameId, exameData);
      
      if (mounted) {
        Navigator.of(context).pop();
        _showSuccessSnackBar('Exame atualizado com sucesso!');
        
        setState(() {
          _examesFuture = apiService.getExames(widget.pacienteId, forceRefresh: true);
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao atualizar exame: $e');
      }
    }
  }

  Future<void> _deleteExame(String exameId) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.deleteExame(widget.pacienteId, exameId);
      
      if (mounted) {
        Navigator.of(context).pop();
        _showSuccessSnackBar('Exame excluído com sucesso!');
        
        setState(() {
          _examesFuture = apiService.getExames(widget.pacienteId, forceRefresh: true);
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao excluir exame: $e');
      }
    }
  }

  Widget? _buildFloatingActionButton() {
    final currentTab = _tabController?.index ?? 0;

    if (currentTab == 0 && (_userRole == 'admin' || _userRole == 'profissional')) {
      return FloatingActionButton.extended(
        heroTag: "patient_details_plan",
        onPressed: () async {
          final consultaId = await Navigator.push<String?>(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePlanPage(pacienteId: widget.pacienteId),
            ),
          );
          if (consultaId != null) _fetchFichaCompleta(consultaId: consultaId);
        },
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('Novo Plano'),
      );
    }
    
    else if (currentTab == 2 && (_userRole == 'admin' || _userRole == 'profissional')) {
      return FloatingActionButton.extended(
        heroTag: "patient_details_exame",
        onPressed: () => _showAddExameDialog(),
        icon: const Icon(Icons.science_rounded),
        label: const Text('Novo Exame'),
      );
    }
    
    else if (currentTab == 3 && (
      _userRole == 'admin' ||
      _userRole == 'super_admin' ||
      _userRole == 'profissional' ||
      (_userRole == 'tecnico' && _hasConfirmedReading)
    )) {
      return FloatingActionButton(
        heroTag: "patient_details_note",
        onPressed: _openProntuarios,
        backgroundColor: _showSuccessFeedback ? AppTheme.successGreen : null,
        child: const Icon(Icons.description_rounded),
      );
    }
    
    else if (currentTab == 5 && (
      _userRole == 'admin' ||
      _userRole == 'profissional' ||
      (_userRole == 'tecnico' && _hasConfirmedReading)
    )) {
      return FloatingActionButton.extended(
        heroTag: "patient_details_suporte",
        onPressed: () => _showAddSuportePsicologicoDialog(),
        icon: const Icon(Icons.psychology_rounded),
        label: const Text('Novo Recurso'),
        backgroundColor: _showSuccessFeedback ? AppTheme.successGreen : null,
      );
    }
    
    else if (_userRole == 'admin' || _userRole == 'profissional') {
      if (currentTab == 6) {
        return FloatingActionButton.extended(
          heroTag: "patient_details_relatorio",
          onPressed: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => CreateReportPage(
                  pacienteId: widget.pacienteId,
                  pacienteNome: widget.pacienteNome ?? 'Paciente',
                ),
              ),
            );

            final abaRelatorios = _tabController?.index ?? 0;

            if (result == true) {
              _initializePage(forceRefresh: true);
            }

            Future.delayed(const Duration(milliseconds: 100), () {
              if (_tabController != null && mounted) {
                _tabController!.animateTo(abaRelatorios);
              }
            });
          },
          icon: const Icon(Icons.assignment_rounded),
          label: const Text('Novo Relatório'),
        );
      }
      else if (_userRole != 'tecnico' && currentTab == 7) {
        return FloatingActionButton.extended(
          heroTag: "patient_details_avaliacao1",
          onPressed: () async {
            final abaAvaliacao = _tabController?.index ?? 0;

            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => AnamneseFormPage(
                  pacienteId: widget.pacienteId,
                  pacienteNome: widget.pacienteNome ?? 'Paciente',
                ),
              ),
            );

            if (result == true) {
              _initializePage(forceRefresh: true);
            }

            Future.delayed(const Duration(milliseconds: 100), () {
              if (_tabController != null && mounted) {
                _tabController!.animateTo(abaAvaliacao);
              }
            });
          },
          icon: const Icon(Icons.history_edu_rounded),
          label: const Text('Nova Avaliação'),
        );
      }
    }
    else if (_userRole != 'tecnico' && currentTab == 6) {
      return FloatingActionButton.extended(
        heroTag: "patient_details_avaliacao2",
        onPressed: () async {
          final abaAvaliacao = _tabController?.index ?? 0;

          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => AnamneseFormPage(
                pacienteId: widget.pacienteId,
                pacienteNome: widget.pacienteNome ?? 'Paciente',
              ),
            ),
          );

          if (result == true) {
            _initializePage(forceRefresh: true);
          }

          Future.delayed(const Duration(milliseconds: 100), () {
            if (_tabController != null && mounted) {
              _tabController!.animateTo(abaAvaliacao);
            }
          });
        },
        icon: const Icon(Icons.history_edu_rounded),
        label: const Text('Nova Avaliação'),
      );
    }

    return null;
  }

  Future<Paciente?> _getPatientPersonalData({bool forceRefresh = false}) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final pacientes = await apiService.getPacientes(forceRefresh: forceRefresh);
      
      return pacientes.firstWhere(
        (p) => p.id == widget.pacienteId,
        orElse: () => throw Exception('Paciente não encontrado'),
      );
    } catch (e) {
      return null;
    }
  }

  Widget _buildPersonalDataCard() {
    return FutureBuilder<Paciente?>(
      future: _getPatientPersonalData(forceRefresh: _refreshPersonalData),
      builder: (context, snapshot) {
        if (_refreshPersonalData && snapshot.connectionState != ConnectionState.waiting) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _refreshPersonalData = false;
            });
          });
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ModernCard(child: LinearProgressIndicator());
        }
        final patient = snapshot.data;
        
        return ModernCard(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_rounded, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  const Text('Dados Pessoais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_userRole == 'admin' || _userRole == 'profissional')
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditPersonalDataPage(
                              patientId: widget.pacienteId,
                              initialData: {
                                'data_nascimento': patient?.dataNascimento?.toIso8601String(),
                                'sexo': patient?.sexo,
                                'estado_civil': patient?.estadoCivil,
                                'profissao': patient?.profissao,
                              },
                            ),
                          ),
                        ).then((updated) {
                          if (updated == true) {
                            setState(() {
                              _refreshPersonalData = true;
                            });
                          }
                        });
                      },
                      tooltip: 'Editar dados pessoais',
                    ),
                ],
              ),
              const Divider(height: 24),
              _buildInfoRow('Idade', formatarIdade(patient?.dataNascimento)),
              const SizedBox(height: 8),
              _buildInfoRow('Sexo', patient?.sexo ?? 'Não informado'),
              const SizedBox(height: 8),
              _buildInfoRow('Estado Civil', patient?.estadoCivil ?? 'Não informado'),
              const SizedBox(height: 8),
              _buildInfoRow('Profissão', patient?.profissao ?? 'Não informado'),
            ],
          ),
        );
      },
    );
  }

}

class _CreateProntuarioDialog extends StatefulWidget {
  final String pacienteId;
  final String pacienteNome;

  const _CreateProntuarioDialog({
    required this.pacienteId,
    required this.pacienteNome,
  });

  @override
  State<_CreateProntuarioDialog> createState() => _CreateProntuarioDialogState();
}

class _CreateProntuarioDialogState extends State<_CreateProntuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _textoController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _textoController.dispose();
    super.dispose();
  }

  Future<void> _createProntuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.createProntuario(widget.pacienteId, {
        'texto': _textoController.text.trim(),
        'tipo': 'anotacao',
        'data_hora': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prontuário criado com sucesso!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar prontuário: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final now = DateTime.now();

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Novo Prontuário'),
          Text(
            widget.pacienteNome,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
          ),
          Text(
            dateFormat.format(now),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: TextFormField(
            controller: _textoController,
            decoration: const InputDecoration(
              labelText: 'Texto do prontuário',
              hintText: 'Digite o conteúdo do prontuário...',
              border: OutlineInputBorder(),
            ),
            maxLines: 8,
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Por favor, digite o texto do prontuário';
              }
              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createProntuario,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Criar'),
        ),
      ],
    );
  }
}