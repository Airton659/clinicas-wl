// lib/screens/relatorio_details_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_service.dart';
import '../models/relatorio_detalhado.dart';
import '../models/relatorio_medico.dart';
import '../models/registro_diario.dart';
import '../models/exame.dart';
import '../models/suporte_psicologico.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/modern_widgets.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';
import 'photo_view_page.dart';

class RelatorioDetailsPage extends StatefulWidget {
  final String relatorioId;

  const RelatorioDetailsPage({
    super.key,
    required this.relatorioId,
  });

  @override
  State<RelatorioDetailsPage> createState() => _RelatorioDetailsPageState();
}

class _RelatorioDetailsPageState extends State<RelatorioDetailsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Future<RelatorioDetalhado>? _relatorioDetalhado;
  bool _isProcessing = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _setupAnimations();
    _loadRelatorioDetalhado();
    _loadUserRole();
  }

  void _loadUserRole() {
    final authService = Provider.of<AuthService>(context, listen: false);
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    final rolesMap = authService.currentUser?.roles;

    if (rolesMap != null) {
      setState(() {
        _userRole = rolesMap[negocioId];
      });
    }
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
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _loadRelatorioDetalhado() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _relatorioDetalhado = apiService.getRelatorioDetalhado(widget.relatorioId);
    });
  }

  Future<void> _aprovarRelatorio() async {
    if (_isProcessing) return;

    final confirmed = await _showConfirmationDialog(
      title: 'Aprovar Relatório',
      content: 'Tem certeza de que deseja aprovar este relatório médico? Esta ação não pode ser desfeita.',
      confirmText: 'Aprovar',
      confirmColor: AppTheme.successGreen,
      icon: Icons.check_circle_outline_rounded,
    );

    if (!confirmed) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.aprovarRelatorio(widget.relatorioId);
      
      if (mounted) {
        _showSuccessMessage('Relatório aprovado com sucesso!');
        Navigator.pop(context, true); // Retorna true para indicar que houve mudança
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Erro ao aprovar relatório: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _recusarRelatorio() async {
    if (_isProcessing) return;

    final motivo = await _showRecusaDialog();
    if (motivo == null || motivo.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.recusarRelatorio(widget.relatorioId, motivo.trim());
      
      if (mounted) {
        _showSuccessMessage('Relatório recusado com sucesso!');
        Navigator.pop(context, true); // Retorna true para indicar que houve mudança
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Erro ao recusar relatório: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
    required IconData icon,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: confirmColor),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<String?> _showRecusaDialog() async {
    final controller = TextEditingController();
    
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: AppTheme.errorRed),
            const SizedBox(width: 12),
            const Text('Recusar Relatório'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Por favor, informe o motivo da recusa:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Motivo da recusa*',
                hintText: 'Descreva os motivos que levaram à recusa do relatório...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Recusar'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorMessage(String message) {
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutralGray50,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: FutureBuilder<RelatorioDetalhado>(
          future: _relatorioDetalhado,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }
            
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }
            
            final relatorioDetalhado = snapshot.data!;
            return _buildContent(relatorioDetalhado);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carregando...'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando detalhes do relatório...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Erro'),
        backgroundColor: AppTheme.errorRed,
        foregroundColor: Colors.white,
      ),
      body: Center(
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
                'Erro ao carregar relatório',
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
                onPressed: _loadRelatorioDetalhado,
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
      ),
    );
  }

  Widget _buildContent(RelatorioDetalhado relatorioDetalhado) {
    return Column(
      children: [
        _buildAppBar(relatorioDetalhado),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildResumoTab(relatorioDetalhado),
              _buildPlanoTab(relatorioDetalhado),
              _buildDiarioTab(relatorioDetalhado),
              _buildExamesTab(relatorioDetalhado),
              _buildFotosTab(relatorioDetalhado),
            ],
          ),
        ),
        if (relatorioDetalhado.relatorio.status == StatusRelatorio.pendente)
          _buildActionButtons(),
      ],
    );
  }

  Widget _buildAppBar(RelatorioDetalhado relatorioDetalhado) {
    final paciente = relatorioDetalhado.paciente;
    final relatorio = relatorioDetalhado.relatorio;
    final dataFormatada = DateFormat('dd/MM/yyyy').format(relatorio.dataCriacao);
    
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryBlue, AppTheme.accentTeal],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Relatório Médico',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${paciente?.nome ?? 'Paciente'} • $dataFormatada',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppTheme.primaryBlue,
        unselectedLabelColor: AppTheme.neutralGray600,
        indicatorColor: AppTheme.primaryBlue,
        tabs: const [
          Tab(text: 'Resumo'),
          Tab(text: 'Plano'),
          Tab(text: 'Diário'),
          Tab(text: 'Exames'),
          Tab(text: 'Fotos'),
        ],
      ),
    );
  }

  Widget _buildResumoTab(RelatorioDetalhado relatorioDetalhado) {
    final paciente = relatorioDetalhado.paciente;
    final relatorio = relatorioDetalhado.relatorio;
    final medico = relatorioDetalhado.medico;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: 'Informações do Paciente',
            icon: Icons.person_rounded,
            children: [
              _buildInfoRow('Nome', paciente?.nome ?? 'Não informado'),
              _buildInfoRow('Email', paciente?.email ?? 'Não informado'),
              _buildInfoRow('Telefone', paciente?.telefone ?? 'Não informado'),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Informações do Relatório',
            icon: Icons.assignment_rounded,
            children: [
              _buildInfoRow('Data de Criação', DateFormat('dd/MM/yyyy • HH:mm').format(relatorio.dataCriacao)),
              _buildInfoRow('Médico Responsável', medico?.nome ?? 'Não informado'),
              _buildInfoRow('Status', _getStatusText(relatorio.status)),
              if (relatorio.dataAvaliacao != null)
                _buildInfoRow('Data de Avaliação', DateFormat('dd/MM/yyyy • HH:mm').format(relatorio.dataAvaliacao!)),
              if (relatorio.motivoRecusa != null)
                _buildInfoRow('Motivo da Recusa', relatorio.motivoRecusa!),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryStats(relatorioDetalhado),
        ],
      ),
    );
  }

  Widget _buildPlanoTab(RelatorioDetalhado relatorioDetalhado) {
    final fichaCompleta = relatorioDetalhado.fichaCompleta;
    
    if (fichaCompleta == null) {
      return const Center(
        child: Text('Nenhum plano de cuidado encontrado.'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fichaCompleta.orientacoes.isNotEmpty) ...[
            _buildSectionHeader('Orientações', Icons.lightbulb_outline_rounded),
            ...fichaCompleta.orientacoes.map((orientacao) => _buildOrientacaoCard(orientacao)),
            const SizedBox(height: 16),
          ],
          
          if (fichaCompleta.medicacoes.isNotEmpty) ...[
            _buildSectionHeader('Medicações', Icons.medication_rounded),
            ...fichaCompleta.medicacoes.map((medicacao) => _buildMedicacaoCard(medicacao)),
            const SizedBox(height: 16),
          ],
          
          if (fichaCompleta.checklist.isNotEmpty) ...[
            _buildSectionHeader('Checklist', Icons.checklist_rounded),
            ...fichaCompleta.checklist.map((item) => _buildChecklistCard(item)),
          ],
        ],
      ),
    );
  }

  Widget _buildDiarioTab(RelatorioDetalhado relatorioDetalhado) {
    final registros = relatorioDetalhado.registrosDiarios;
    
    if (registros.isEmpty) {
      return const Center(
        child: Text('Nenhum registro encontrado no diário.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: registros.length,
      itemBuilder: (context, index) {
        final registro = registros[index];
        return _buildRegistroCard(registro);
      },
    );
  }

  Widget _buildExamesTab(RelatorioDetalhado relatorioDetalhado) {
    final exames = relatorioDetalhado.exames;
    
    if (exames.isEmpty) {
      return const Center(
        child: Text('Nenhum exame encontrado.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: exames.length,
      itemBuilder: (context, index) {
        final exame = exames[index];
        return _buildExameCard(exame);
      },
    );
  }

  Widget _buildFotosTab(RelatorioDetalhado relatorioDetalhado) {
    final fotos = relatorioDetalhado.fotos;
    
    if (fotos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: AppTheme.neutralGray400,
            ),
            SizedBox(height: 16),
            Text('Nenhuma foto anexada ao relatório.'),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: fotos.length,
      itemBuilder: (context, index) {
        final foto = fotos[index];
        return _buildFotoCard(foto);
      },
    );
  }

  Widget _buildActionButtons() {
    // Só mostra botões de aprovação/reprovação para médicos
    if (_userRole != 'medico') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _recusarRelatorio,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined),
                label: const Text('Recusar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _aprovarRelatorio,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Aprovar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.neutralGray600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.neutralGray800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStats(RelatorioDetalhado relatorioDetalhado) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              const Text(
                'Resumo do Conteúdo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Registros Diários',
                  relatorioDetalhado.registrosDiarios.length.toString(),
                  Icons.event_note_rounded,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Exames',
                  relatorioDetalhado.exames.length.toString(),
                  Icons.science_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Fotos',
                  relatorioDetalhado.fotos.length.toString(),
                  Icons.photo_library_rounded,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Suporte Psico.',
                  relatorioDetalhado.suportePsicologico.length.toString(),
                  Icons.psychology_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.neutralGray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.neutralGray200),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryBlue, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlue,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.neutralGray600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Placeholder methods for building cards - implement based on your models
  Widget _buildOrientacaoCard(orientacao) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Text('Orientação: ${orientacao.toString()}'), // Implement based on Orientacao model
    );
  }

  Widget _buildMedicacaoCard(medicacao) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Text('Medicação: ${medicacao.toString()}'), // Implement based on Medicacao model
    );
  }

  Widget _buildChecklistCard(item) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Text('Checklist: ${item.toString()}'), // Implement based on ChecklistItem model
    );
  }

  Widget _buildRegistroCard(RegistroDiario registro) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getTipoRegistroIcon(registro.tipo), color: AppTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                _getTipoRegistroText(registro.tipo),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                DateFormat('dd/MM • HH:mm').format(registro.dataHora),
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.neutralGray600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (registro.anotacoes != null)
            Text(registro.anotacoes!),
          const SizedBox(height: 4),
          Text(
            'Por: ${registro.tecnico.nome}',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.neutralGray600,
            ),
          ),
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
              const Icon(Icons.science_rounded, color: AppTheme.successGreen, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  exame.nomeExame,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (exame.descricao?.isNotEmpty == true)
            Text(exame.descricao!),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                exame.dataExame != null 
                    ? 'Data: ${DateFormat('dd/MM/yyyy').format(exame.dataExame!)}'
                    : 'Data: Não informada',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.neutralGray600,
                ),
              ),
              if (exame.horarioExame?.isNotEmpty == true) ...[
                Text(
                  ' • ${exame.horarioExame}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.neutralGray600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

// Dentro da classe _RelatorioDetailsPageState em lib/screens/relatorio_details_page.dart

  Widget _buildFotoCard(String fotoUrl) {
    // CHEGA DE MODERN CARD. VAMOS USAR UM CONTAINER BEM CHAMATIVO.
    return Container(
      // MUDANÇA VISUAL IMPACTANTE: Borda roxa para ter certeza que estamos no lugar certo.
      decoration: BoxDecoration(
        color: Colors.grey[200], // Fundo cinza claro para destacar a borda.
        border: Border.all(
          color: Colors.purple, // A COR DA BIZARRICE
          width: 4.0,           // BEM GROSSA PRA VER DE LONGE
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      // ClipRRect para manter as bordas da imagem arredondadas.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        // MouseRegion para o cursor de clique na web.
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          // GestureDetector para a ação de clique/toque.
          child: GestureDetector(
            onTap: () {
              // Navegação para a página de visualização da foto.
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PhotoViewPage(imageUrl: fotoUrl),
                ),
              );
            },
            // Hero para a animação de transição.
            child: Hero(
              tag: fotoUrl,
              child: Image.network(
                fotoUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Icon(Icons.error_outline, color: Colors.red, size: 40));
                },
              ),
            ),
          ),
        ),
      ),
    );
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

  IconData _getTipoRegistroIcon(TipoRegistro tipo) {
    switch (tipo) {
      case TipoRegistro.sinaisVitais:
        return Icons.monitor_heart_rounded;
      case TipoRegistro.medicacao:
        return Icons.medication_rounded;
      case TipoRegistro.intercorrencia:
        return Icons.warning_rounded;
      case TipoRegistro.atividade:
        return Icons.directions_run_rounded;
      case TipoRegistro.anotacao:
        return Icons.note_rounded;
      case TipoRegistro.anamnese:
        return Icons.assignment_rounded;
    }
  }

  String _getTipoRegistroText(TipoRegistro tipo) {
    switch (tipo) {
      case TipoRegistro.sinaisVitais:
        return 'Sinais Vitais';
      case TipoRegistro.medicacao:
        return 'Medicação';
      case TipoRegistro.intercorrencia:
        return 'Intercorrência';
      case TipoRegistro.atividade:
        return 'Atividade';
      case TipoRegistro.anotacao:
        return 'Anotação';
      case TipoRegistro.anamnese:
        return 'Anamnese';
    }
  }
}