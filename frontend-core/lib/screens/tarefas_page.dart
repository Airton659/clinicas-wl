// lib/screens/tarefas_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../api/api_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/modern_widgets.dart';
import '../models/tarefa_agendada.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/notification_types.dart';

class TarefasPage extends StatefulWidget {
  final String pacienteId;
  final String pacienteNome;

  const TarefasPage({
    super.key,
    required this.pacienteId,
    required this.pacienteNome,
  });

  @override
  State<TarefasPage> createState() => _TarefasPageState();
}

class _TarefasPageState extends State<TarefasPage> {
  late Future<List<TarefaAgendada>> _tarefasFuture;
  String _filtroStatus = 'pendente';
  String? _userRole;

  // Variável para controlar o "ouvinte" de notificações
  late StreamSubscription<NotificationType?> _notificationSubscription;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    _userRole = authService.currentUser?.roles?[negocioId];
    _loadTarefas();
    _setupNotificationListener();
  }

  // Método para configurar o "ouvinte" de notificações
  void _setupNotificationListener() {
    final notificationService = NotificationService();
    _notificationSubscription =
        notificationService.notificationStream.listen((notificationType) {
      // Verifica se a notificação é relacionada a tarefas
      if (notificationType == NotificationType.tarefaConcluida ||
          notificationType == NotificationType.tarefaAtrasada ||
          notificationType == NotificationType.tarefaAtrasadaTecnico) {
        debugPrint(
            "✅ Notificação de tarefa [${notificationType?.toString().split('.').last}] recebida. Verificando se é para este paciente...");

        // Obtém a notificação mais recente
        final latestNotification = notificationService.notifications.first;
        final notificationPatientId = latestNotification.data['paciente_id'];

        // Compara o ID do paciente da notificação com o ID do paciente desta tela
        if (notificationPatientId == widget.pacienteId) {
          debugPrint("✅ SIM! A notificação é para o paciente atual (${widget.pacienteId}). Atualizando lista de tarefas...");
          if (mounted) {
            _loadTarefas(forceRefresh: true);
          }
        } else {
          debugPrint("❌ NÃO. A notificação é para outro paciente ($notificationPatientId). Ignorando.");
        }
      }
    });
  }

  @override
  void dispose() {
    // Cancela a inscrição para evitar vazamento de memória
    _notificationSubscription.cancel();
    super.dispose();
  }

  void _loadTarefas({bool forceRefresh = false}) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _tarefasFuture = apiService.getTarefas(widget.pacienteId, status: _filtroStatus);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutralGray50,
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: FutureBuilder<List<TarefaAgendada>>(
              future: _tarefasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ModernEmptyState(
                    icon: Icons.error_outline,
                    title: 'Erro ao Carregar Tarefas',
                    subtitle: 'Não foi possível buscar as tarefas. Tente novamente.',
                    buttonText: 'Atualizar',
                    onButtonPressed: _loadTarefas,
                  );
                }
                final tarefas = snapshot.data ?? [];
                if (tarefas.isEmpty) {
                  return ModernEmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'Nenhuma Tarefa Encontrada',
                    subtitle: 'Não há tarefas com o filtro selecionado.',
                  );
                }

                // Ordena tarefas por data/hora - mais recentes primeiro
                tarefas.sort((a, b) {
                  return b.dataHoraLimite.compareTo(a.dataHoraLimite); // Ordem decrescente (mais recentes primeiro)
                });

                return RefreshIndicator(
                  onRefresh: () async => _loadTarefas(forceRefresh: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tarefas.length,
                    itemBuilder: (context, index) {
                      return _buildTarefaCard(tarefas[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: (_userRole == 'admin' || _userRole == 'profissional')
          ? FloatingActionButton.extended(
              heroTag: "tarefas_page_add",
              onPressed: _showAddTarefaDialog,
              label: const Text('Nova Tarefa'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          FilterChip(
            label: const Text('Pendentes'),
            selected: _filtroStatus == 'pendente',
            onSelected: (selected) {
              if (selected) setState(() => _filtroStatus = 'pendente');
              _loadTarefas();
            },
          ),
          FilterChip(
            label: const Text('Concluídas'),
            selected: _filtroStatus == 'concluida',
            onSelected: (selected) {
              if (selected) setState(() => _filtroStatus = 'concluida');
              _loadTarefas();
            },
          ),
          FilterChip(
            label: const Text('Atrasadas'),
            selected: _filtroStatus == 'atrasada',
            onSelected: (selected) {
              if (selected) setState(() => _filtroStatus = 'atrasada');
              _loadTarefas();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTarefaCard(TarefaAgendada tarefa) {
    final status = tarefa.status;
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case StatusTarefa.concluida:
        statusColor = AppTheme.successGreen;
        statusIcon = Icons.check_circle_rounded;
        statusText = 'CONCLUÍDA';
        break;
      case StatusTarefa.atrasada:
        statusColor = AppTheme.errorRed;
        statusIcon = Icons.timer_off_rounded;
        statusText = 'ATRASADA';
        break;
      default: // Pendente
        statusColor = AppTheme.warningOrange;
        statusIcon = Icons.pending_actions_rounded;
        statusText = 'PENDENTE';
    }

    final podeConcluir = ['admin', 'profissional', 'tecnico'].contains(_userRole) && status != StatusTarefa.concluida;

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
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tarefa.descricao,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              if (podeConcluir)
                Checkbox(
                  value: tarefa.foiConcluida,
                  onChanged: (value) => _concluirTarefa(tarefa),
                  activeColor: AppTheme.successGreen,
                )
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow('Prazo:', DateFormat('dd/MM/yyyy \'às\' HH:mm').format(tarefa.dataHoraLimite)),
          if (tarefa.criadoPor != null)
            _buildInfoRow('Criada por:', tarefa.criadoPor!.nome ?? 'Não informado'),
          if (tarefa.foiConcluida && tarefa.executadoPor != null) ...[
            _buildInfoRow('Concluída por:', tarefa.executadoPor!.nome ?? 'Não informado'),
            _buildInfoRow('Em:', DateFormat('dd/MM/yyyy \'às\' HH:mm').format(tarefa.dataConclusao!)),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: StatusBadge(text: statusText, color: statusColor),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _concluirTarefa(TarefaAgendada tarefa) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Conclusão'),
        content: const Text('Tem certeza de que deseja marcar esta tarefa como concluída?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirmar')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        await apiService.concluirTarefa(tarefa.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarefa concluída com sucesso!'), backgroundColor: AppTheme.successGreen),
        );
        _loadTarefas();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao concluir tarefa: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  void _showAddTarefaDialog() {
    final descricaoController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nova Tarefa Essencial'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descricaoController,
                    decoration: const InputDecoration(labelText: 'Descrição da Tarefa'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(selectedDate == null ? 'Selecionar data' : DateFormat('dd/MM/yyyy').format(selectedDate!)),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setDialogState(() => selectedDate = date);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: Text(selectedTime == null ? 'Selecionar hora' : selectedTime!.format(context)),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setDialogState(() => selectedTime = time);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    if (descricaoController.text.isNotEmpty && selectedDate != null && selectedTime != null) {
                      final dataHoraLimite = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                      _createTarefa(descricaoController.text, dataHoraLimite);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Criar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createTarefa(String descricao, DateTime dataHoraLimite) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.createTarefa(widget.pacienteId, {
        'descricao': descricao,
        'dataHoraLimite': dataHoraLimite.toUtc().toIso8601String(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarefa criada com sucesso!'), backgroundColor: AppTheme.successGreen),
      );
      _loadTarefas();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar tarefa: $e'), backgroundColor: AppTheme.errorRed),
      );
    }
  }
}