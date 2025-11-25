// lib/screens/patient_reports_history_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_service.dart';
import '../models/relatorio_medico.dart';
import '../models/usuario.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/modern_widgets.dart';
import 'create_report_page.dart';
import 'relatorio_pdf_page.dart';
import 'package:intl/intl.dart';

class PatientReportsHistoryPage extends StatefulWidget {
  final String pacienteId;
  final String pacienteNome;
  final bool showFloatingActionButton; // Novo parâmetro para controlar FAB

  const PatientReportsHistoryPage({
    super.key,
    required this.pacienteId,
    required this.pacienteNome,
    this.showFloatingActionButton = true, // Por padrão mostra o FAB
  });

  @override
  State<PatientReportsHistoryPage> createState() => _PatientReportsHistoryPageState();
}

class _PatientReportsHistoryPageState extends State<PatientReportsHistoryPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Future<List<RelatorioMedico>>? _relatoriosFuture;
  Map<String, String> _medicosNomes = {};

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadRelatorios();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadRelatorios() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _relatoriosFuture = _loadRelatoriosAndMedicos(apiService);
    });
  }

  Future<List<RelatorioMedico>> _loadRelatoriosAndMedicos(ApiService apiService) async {
    try {
      // Carregar relatórios e médicos em paralelo
      final futures = await Future.wait([
        apiService.getRelatoriosPaciente(widget.pacienteId),
        apiService.getAllUsersInBusiness(status: 'ativo'),
      ]);
      
      final relatorios = futures[0] as List<RelatorioMedico>;
      final usuarios = futures[1] as List<Usuario>;
      
      // Criar mapa de médicos
      _medicosNomes.clear();
      for (final usuario in usuarios) {
        if (usuario.roles?.values.contains('medico') == true) {
          final userId = usuario.id;
          final userName = usuario.nome ?? 'Médico';
          if (userId != null) {
            _medicosNomes[userId] = userName;
          }
        }
      }
      
      return relatorios;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _createNewReport() async {
    try {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => CreateReportPage(
            pacienteId: widget.pacienteId,
            pacienteNome: widget.pacienteNome,
          ),
        ),
      );

      if (result == true) {
        _loadRelatorios();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir tela de criação: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _openRelatorioDetails(RelatorioMedico relatorio) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RelatorioPdfPage(
          relatorioId: relatorio.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutralGray50,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: FutureBuilder<List<RelatorioMedico>>(
          future: _relatoriosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }
            
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }
            
            final relatorios = snapshot.data ?? [];
            
            if (relatorios.isEmpty) {
              return _buildEmptyStateWithHeader();
            }
            
            return _buildRelatoriosListWithHeader(relatorios);
          },
        ),
      ),
      floatingActionButton: widget.showFloatingActionButton
        ? FloatingActionButton.extended(
            heroTag: "patient_reports_fab",
            onPressed: _createNewReport,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Novo Relatório'),
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
          )
        : null,
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Carregando relatórios...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.errorRed,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Erro ao carregar relatórios',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: AppTheme.neutralGray600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadRelatorios,
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

  Widget _buildEmptyStateWithHeader() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSectionHeader(
          'Relatórios Médicos',
          Icons.assignment_rounded,
          AppTheme.primaryBlue,
        ),
        const SizedBox(height: 32),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.assignment_outlined,
              color: AppTheme.neutralGray400,
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              'Nenhum Relatório Criado',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.neutralGray700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Este paciente ainda não possui relatórios médicos. Crie o primeiro relatório tocando no botão abaixo.',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.neutralGray600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _createNewReport,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Criar Primeiro Relatório'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.assignment_outlined,
            color: AppTheme.neutralGray400,
            size: 80,
          ),
          const SizedBox(height: 24),
          const Text(
            'Nenhum Relatório Criado',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.neutralGray700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Este paciente ainda não possui relatórios médicos. Crie o primeiro relatório tocando no botão abaixo.',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.neutralGray600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _createNewReport,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Criar Primeiro Relatório'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatoriosListWithHeader(List<RelatorioMedico> relatorios) {
    // Ordenar relatórios por data (mais recente primeiro)
    relatorios.sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
    
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildSectionHeader(
                'Relatórios Médicos',
                Icons.assignment_rounded,
                AppTheme.primaryBlue,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadRelatorios,
              tooltip: 'Atualizar',
              color: AppTheme.primaryBlue,
            ),
          ],
        ),
        ...relatorios.map((relatorio) => _buildRelatorioCard(relatorio)),
      ],
    );
  }

  Widget _buildRelatoriosList(List<RelatorioMedico> relatorios) {
    // Ordenar relatórios por data (mais recente primeiro)
    relatorios.sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: relatorios.length,
      itemBuilder: (context, index) {
        final relatorio = relatorios[index];
        return _buildRelatorioCard(relatorio);
      },
    );
  }

  Widget _buildRelatorioCard(RelatorioMedico relatorio) {
    // Converter UTC para horário de São Paulo (UTC-3)
    final dataLocal = relatorio.dataCriacao.subtract(const Duration(hours: 3));
    final dataFormatada = DateFormat('dd/MM/yyyy • HH:mm').format(dataLocal);

    // Buscar nome do médico e criador
    String medicoNome = _medicosNomes[relatorio.medicoId] ?? 'Médico não informado';
    String criadorNome = relatorio.criadoPor?.nome ?? 'Não informado';

    final statusColor = _getStatusColor(relatorio.status);
    final statusText = _getStatusText(relatorio.status);
    final statusIcon = _getStatusIcon(relatorio.status);

    return ModernCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _openRelatorioDetails(relatorio),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Relatório Médico',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.neutralGray800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusText.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Médico: Dr. $medicoNome',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.neutralGray600,
                      ),
                    ),
                    Text(
                      'Criado por: $criadorNome',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.neutralGray600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Criado em $dataFormatada',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.neutralGray500,
                      ),
                    ),
                  ],
                ),
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
          if (relatorio.dataAvaliacao != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: AppTheme.neutralGray500,
                ),
                const SizedBox(width: 4),
                Text(
                  'Avaliado em ${DateFormat('dd/MM/yyyy • HH:mm').format(relatorio.dataAvaliacao!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.neutralGray500,
                  ),
                ),
              ],
            ),
          ],
          if (relatorio.motivoRecusa != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppTheme.errorRed,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Motivo da Recusa:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.errorRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    relatorio.motivoRecusa!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.errorRed,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(StatusRelatorio status) {
    switch (status) {
      case StatusRelatorio.pendente:
        return AppTheme.warningOrange;
      case StatusRelatorio.aprovado:
        return AppTheme.successGreen;
      case StatusRelatorio.recusado:
        return AppTheme.errorRed;
    }
  }

  String _getStatusText(StatusRelatorio status) {
    switch (status) {
      case StatusRelatorio.pendente:
        return 'Pendente';
      case StatusRelatorio.aprovado:
        return 'Aprovado';
      case StatusRelatorio.recusado:
        return 'Recusado';
    }
  }

  IconData _getStatusIcon(StatusRelatorio status) {
    switch (status) {
      case StatusRelatorio.pendente:
        return Icons.pending_actions_rounded;
      case StatusRelatorio.aprovado:
        return Icons.check_circle_outline_rounded;
      case StatusRelatorio.recusado:
        return Icons.cancel_outlined;
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, [Color? color]) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (color ?? AppTheme.primaryBlue).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color ?? AppTheme.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.neutralGray800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}