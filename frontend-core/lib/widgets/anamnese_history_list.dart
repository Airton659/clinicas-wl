// lib/widgets/anamnese_history_list.dart

import 'package:analicegrubert/api/api_service.dart';
import 'package:analicegrubert/core/theme/app_theme.dart';
import 'package:analicegrubert/core/widgets/modern_widgets.dart';
import 'package:analicegrubert/models/anamnese.dart';
import 'package:analicegrubert/models/usuario.dart';
import 'package:analicegrubert/screens/anamnese_form_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AnamneseHistoryList extends StatefulWidget {
  final String pacienteId;
  final String pacienteNome;

  const AnamneseHistoryList({
    super.key,
    required this.pacienteId,
    required this.pacienteNome,
  });

  @override
  State<AnamneseHistoryList> createState() => _AnamneseHistoryListState();
}

class _AnamneseHistoryListState extends State<AnamneseHistoryList> {
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      final futures = [
        apiService.getAnamneseHistory(widget.pacienteId),
        apiService.getAllUsersInBusiness(status: 'all'),
      ];

      _dataFuture = Future.wait(futures).then((results) {
        return {
          'history': results[0] as List<Anamnese>,
          'users': results[1] as List<Usuario>,
        };
      });
    });
  }

  Future<void> _navigateToForm({Anamnese? anamnese}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AnamneseFormPage(
          pacienteId: widget.pacienteId,
          pacienteNome: widget.pacienteNome,
          anamnese: anamnese,
          isReadOnly: anamnese != null,
        ),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: ModernEmptyState(
                icon: Icons.error_outline,
                title: 'Erro ao Carregar Histórico',
                subtitle: snapshot.error.toString(),
                buttonText: 'Tentar Novamente',
                onButtonPressed: _loadData,
              ),
            );
          }
          if (!snapshot.hasData || (snapshot.data!['history'] as List).isEmpty) {
            return Center(
              child: ModernEmptyState(
                icon: Icons.history_edu_rounded,
                title: 'Nenhuma Avaliação Encontrada',
                subtitle: 'Ainda não há fichas de avaliação para este paciente.',
                buttonText: 'Criar Nova Ficha',
                onButtonPressed: () => _navigateToForm(),
              ),
            );
          }

          final history = snapshot.data!['history'] as List<Anamnese>;
          final users = snapshot.data!['users'] as List<Usuario>;

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final anamnese = history[index];
                final responsavel = users.firstWhere(
                  (user) => user.id == anamnese.responsavelId || user.firebaseUid == anamnese.responsavelId,
                  orElse: () => const Usuario.empty(),
                );
                
                return ModernCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  onTap: () => _navigateToForm(anamnese: anamnese),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.description_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Avaliação de ${DateFormat('dd/MM/yyyy \'às\' HH:mm').format(anamnese.dataAvaliacao.toLocal())}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Responsável: ${responsavel.nome}',
                              style: const TextStyle(
                                color: AppTheme.neutralGray500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.neutralGray400, size: 16),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
      // FloatingActionButton removido - agora é gerenciado pelo PatientDetailsPage
    );
  }
}