// lib/screens/relatorio_pdf_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_service.dart';
import '../models/relatorio_medico.dart';
import '../models/usuario.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:analicegrubert/screens/photo_view_page.dart';

class RelatorioPdfPage extends StatefulWidget {
  final String relatorioId;

  const RelatorioPdfPage({
    super.key,
    required this.relatorioId,
  });

  @override
  State<RelatorioPdfPage> createState() => _RelatorioPdfPageState();
}

class _RelatorioPdfPageState extends State<RelatorioPdfPage> {
  Future<Map<String, dynamic>>? _relatorioData;
  bool _isProcessing = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadRelatorioData();
    _loadUserRole();
  }

  void _loadUserRole() {
    final authService = Provider.of<AuthService>(context, listen: false);
    const negocioId = "AvcbtyokbHx82pYbiraE";
    final rolesMap = authService.currentUser?.roles;

    if (rolesMap != null) {
      setState(() {
        _userRole = rolesMap[negocioId];
      });
    }
  }

  void _loadRelatorioData() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _relatorioData = _fetchRelatorioCompleto(apiService);
    });
  }

  Future<Map<String, dynamic>> _fetchRelatorioCompleto(ApiService apiService) async {
    try {
      // Tentar usar o endpoint getRelatorioDetalhado que deve ter mais informações
      final relatorioDetalhado = await apiService.getRelatorioDetalhado(widget.relatorioId);
      
      
      return {
        'relatorio': relatorioDetalhado.relatorio,
        'paciente': relatorioDetalhado.paciente,
      };
    } catch (e) {
      
      // Fallback: usar relatório básico sem dados do paciente
      final relatoriosMedicos = await apiService.getRelatoriosPendentes();
      final relatorio = relatoriosMedicos.firstWhere((r) => r.id == widget.relatorioId);
      
      
      return {
        'relatorio': relatorio,
        'paciente': null, // Sem dados do paciente no fallback
      };
    }
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
        Navigator.pop(context, true);
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
        Navigator.pop(context, true);
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Relatório Médico'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _relatorioData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Carregando relatório...'),
                ],
              ),
            );
          }
          
          if (snapshot.hasError) {
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
                      'Erro ao carregar relatório',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: TextStyle(
                        color: AppTheme.neutralGray600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadRelatorioData,
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
          
          final data = snapshot.data!;
          final relatorio = data['relatorio'] as RelatorioMedico;
          final paciente = data['paciente'] as Usuario?;
          
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dados pessoais do paciente
                      _buildPatientHeader(paciente, relatorio),
                      const SizedBox(height: 24),
                      
                      // Campos de texto do relatório
                      _buildReportContent(relatorio),
                      const SizedBox(height: 24),
                      
                      // Fotos
                      if (relatorio.fotos.isNotEmpty) _buildPhotosSection(relatorio.fotos),
                    ],
                  ),
                ),
              ),
              
              // Botões de ação (se pendente)
              if (relatorio.status == StatusRelatorio.pendente)
                _buildActionButtons(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPatientHeader(Usuario? paciente, RelatorioMedico relatorio) {
    // Converter UTC para horário local do Brasil (UTC-3)
    final dataLocal = relatorio.dataCriacao.toLocal();
    final dataFormatada = DateFormat('dd/MM/yyyy • HH:mm').format(dataLocal);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.neutralGray50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutralGray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_rounded, color: AppTheme.primaryBlue, size: 24),
              const SizedBox(width: 12),
              const Text(
                'DADOS DO PACIENTE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (paciente != null) ...[
            _buildInfoRow('Nome Completo:', paciente.nome ?? 'Não informado'),
            _buildInfoRow('Email:', paciente.email ?? 'Não informado'),
            _buildInfoRow('Telefone:', paciente.telefone ?? 'Não informado'),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warningOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppTheme.warningOrange, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Dados do paciente serão carregados quando disponíveis',
                      style: TextStyle(color: AppTheme.warningOrange, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          const Divider(color: AppTheme.neutralGray300),
          const SizedBox(height: 8),

          // Nome do criador do relatório
          if (relatorio.criadoPor != null) ...[
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, color: AppTheme.neutralGray600, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Criado por: ${relatorio.criadoPor!.nome}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.neutralGray700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Data de criação
          Row(
            children: [
              const Icon(Icons.access_time_rounded, color: AppTheme.neutralGray600, size: 16),
              const SizedBox(width: 8),
              Text(
                'Relatório criado em $dataFormatada',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.neutralGray600,
                ),
              ),
            ],
          ),
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
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.neutralGray700,
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

  Widget _buildReportContent(RelatorioMedico relatorio) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutralGray200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_rounded, color: AppTheme.primaryBlue, size: 24),
              const SizedBox(width: 12),
              const Text(
                'CONTEÚDO DO RELATÓRIO',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.neutralGray50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.neutralGray200),
            ),
            child: Text(
              relatorio.conteudo?.isNotEmpty == true 
                  ? relatorio.conteudo!
                  : 'Este relatório ainda não possui conteúdo preenchido.\nO conteúdo pode ser adicionado pelo profissional responsável.',
              style: TextStyle(
                fontSize: 15,
                color: relatorio.conteudo?.isNotEmpty == true 
                    ? AppTheme.neutralGray800
                    : AppTheme.neutralGray500,
                height: 1.6,
                fontStyle: relatorio.conteudo?.isNotEmpty == true 
                    ? FontStyle.normal
                    : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection(List<String> fotos) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutralGray200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_rounded, color: AppTheme.primaryBlue, size: 24),
              const SizedBox(width: 12),
              Text(
                'FOTOGRAFIAS ANEXAS (${fotos.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: fotos.length,
            itemBuilder: (context, index) {
              final fotoUrl = fotos[index];
              
              // AQUI ESTÁ A LÓGICA CORRIGIDA E FINAL
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PhotoViewPage(imageUrl: fotoUrl),
                      ),
                    );
                  },
                  child: Hero(
                    tag: fotoUrl, // Tag para a animação Hero
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.neutralGray200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          fotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppTheme.neutralGray100,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image_rounded,
                                  color: AppTheme.neutralGray400,
                                  size: 48,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Erro ao carregar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.neutralGray400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: AppTheme.neutralGray100,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    // Só mostra botões de aprovação/reprovação para médicos
    if (_userRole != 'medico') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
}