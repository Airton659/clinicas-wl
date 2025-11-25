// lib/screens/notifications_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/notification_provider.dart';
import '../models/notificacao.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/modern_widgets.dart';
import '../screens/patient_details_page.dart';
import '../screens/client_dashboard.dart';
import '../services/auth_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    // Carregar notificações ao abrir a tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Adicionado forceRefresh: true para garantir que os dados mais recentes sejam sempre carregados
      context.read<NotificationProvider>().loadNotifications(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutralGray50,
      appBar: AppBar(
        title: const Text(
          'Notificações',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              if (notificationProvider.unreadCount > 0) {
                return TextButton(
                  onPressed: () => _markAllAsRead(notificationProvider),
                  child: const Text(
                    'Ler todas',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, child) {
          if (notificationProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final notifications = notificationProvider.notifications;

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () => notificationProvider.loadNotifications(forceRefresh: true),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildNotificationCard(notification, notificationProvider);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: ModernEmptyState(
        icon: Icons.notifications_none_outlined,
        title: 'Sem notificações',
        subtitle: 'Você não possui notificações no momento.',
        buttonText: 'Atualizar',
        onButtonPressed: () {
          context.read<NotificationProvider>().loadNotifications(forceRefresh: true);
        },
      ),
    );
  }

  Widget _buildNotificationCard(Notificacao notification, NotificationProvider provider) {
    final isUnread = !notification.lida;
    final timeAgo = _getTimeAgo(notification.dataCriacao);
    final icon = _getNotificationIcon(notification.tipo);
    final color = _getNotificationColor(notification.tipo);

    return ModernCard(
      onTap: () => _handleNotificationTap(notification, provider),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isUnread ? AppTheme.primaryBlue.withValues(alpha: 0.05) : null,
          border: isUnread ? Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.1)) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
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
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                              color: AppTheme.neutralGray800,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.neutralGray600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeAgo,
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
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String? tipo) {
    switch (tipo) {
      case 'RELATORIO_AVALIADO':
        return Icons.assignment_turned_in_outlined;
      case 'PLANO_ATUALIZADO':
        return Icons.medical_services_outlined;
      case 'ASSOCIACAO_PROFISSIONAL':
        return Icons.person_add_outlined;
      case 'CHECKLIST_CONCLUIDO':
        return Icons.check_circle_outline;
      case 'NOVO_AGENDAMENTO':
        return Icons.event_outlined;
      case 'AGENDAMENTO_CANCELADO':
        return Icons.event_busy_outlined;
      case 'LEMBRETE_PERSONALIZADO':
        return Icons.alarm_outlined;
      case 'NOVO_RELATORIO_MEDICO':
        return Icons.assignment_late_outlined;
      case 'NOVO_REGISTRO_DIARIO':
        return Icons.edit_note_rounded;
      case 'TAREFA_CONCLUIDA':
        return Icons.task_alt_rounded;
      case 'TAREFA_ATRASADA':
      case 'TAREFA_ATRASADA_TECNICO':
        return Icons.timer_off_outlined;
      case 'LEMBRETE_EXAME':
        return Icons.access_alarm_rounded;
      case 'EXAME_CRIADO':
        return Icons.science_rounded;
      case 'SUPORTE_ADICIONADO':
        return Icons.psychology_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getNotificationColor(String? tipo) {
    switch (tipo) {
      case 'RELATORIO_AVALIADO':
        return AppTheme.successGreen;
      case 'PLANO_ATUALIZADO':
        return AppTheme.primaryBlue;
      case 'ASSOCIACAO_PROFISSIONAL':
        return AppTheme.accentTeal;
      case 'CHECKLIST_CONCLUIDO':
        return AppTheme.successGreen;
      case 'NOVO_AGENDAMENTO':
        return AppTheme.primaryBlue;
      case 'AGENDAMENTO_CANCELADO':
        return AppTheme.errorRed;
      case 'LEMBRETE_PERSONALIZADO':
        return AppTheme.warningOrange;
      case 'NOVO_RELATORIO_MEDICO':
        return AppTheme.warningOrange;
      case 'NOVO_REGISTRO_DIARIO':
        return AppTheme.accentTeal;
      case 'TAREFA_CONCLUIDA':
        return AppTheme.successGreen;
      case 'TAREFA_ATRASADA':
      case 'TAREFA_ATRASADA_TECNICO':
        return AppTheme.errorRed;
      case 'LEMBRETE_EXAME':
        return AppTheme.warningOrange;
      case 'EXAME_CRIADO':
        return AppTheme.primaryBlue;
      case 'SUPORTE_ADICIONADO':
        return AppTheme.successGreen;
      default:
        return AppTheme.neutralGray600;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Agora';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m atrás';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h atrás';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d atrás';
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  bool _isClient() {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      const negocioId = "AvcbtyokbHx82pYbiraE";
      final userRole = authService.currentUser?.roles?[negocioId];
      final isClient = userRole == 'cliente' || userRole == 'paciente' || userRole == null;
      debugPrint('🔍 NotificationsPage - É cliente? $isClient (role: $userRole)');
      return isClient;
    } catch (e) {
      debugPrint('❌ Erro ao verificar role: $e');
      return true; // Default para cliente em caso de erro
    }
  }

  void _handleNotificationTap(Notificacao notification, NotificationProvider provider) {
    if (!notification.lida) {
      provider.markAsRead(notification.id);
    }
    // Navegação removida conforme solicitado pelo cliente
    // _navigateToRelatedScreen(notification);
  }

  void _navigateToRelatedScreen(Notificacao notification) {
    final relacionado = notification.relacionado;
    if (relacionado == null) return;

    switch (notification.tipo) {
      case 'RELATORIO_AVALIADO':
      case 'NOVO_RELATORIO_MEDICO':
        final relatorioId = relacionado['relatorio_id'];
        if (relatorioId != null) {
        }
        break;

      case 'PLANO_ATUALIZADO':
      case 'NOVO_REGISTRO_DIARIO':
        final pacienteId = relacionado['paciente_id'];
        if (pacienteId != null) {
        }
        break;

      case 'ASSOCIACAO_PROFISSIONAL':
        final pacienteId = relacionado['paciente_id'];
        if (pacienteId != null) {
        }
        break;

      case 'CHECKLIST_CONCLUIDO':
        final pacienteId = relacionado['paciente_id'];
        if (pacienteId != null) {
        }
        break;

      case 'TAREFA_CONCLUIDA':
      case 'TAREFA_ATRASADA':
      case 'TAREFA_ATRASADA_TECNICO':
        final pacienteId = relacionado['paciente_id'];
        if (pacienteId != null) {
        }
        break;

      case 'LEMBRETE_EXAME':
      case 'EXAME_CRIADO':
        final pacienteId = relacionado['paciente_id'];
        if (pacienteId != null) {
          debugPrint('🚀 NotificationsPage - Navegando para exames...');
          if (_isClient()) {
            debugPrint('📱 Navegando cliente para dashboard');
            // Para clientes, navegar para o dashboard (onde eles veem seus exames)
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const ClientDashboard(),
              ),
              (route) => false, // Remove todas as rotas anteriores
            );
          } else {
            debugPrint('👩‍⚕️ Navegando profissional para PatientDetailsPage');
            // Para profissionais, navegar para PatientDetailsPage
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PatientDetailsPage(
                  pacienteId: pacienteId,
                  initialTabIndex: 1, // Índice da aba de exames
                ),
              ),
            );
          }
        }
        break;

      case 'SUPORTE_ADICIONADO':
        final pacienteId = relacionado['paciente_id'];
        if (pacienteId != null) {
          debugPrint('🚀 NotificationsPage - Navegando para suporte psicológico...');
          if (_isClient()) {
            debugPrint('📱 Navegando cliente para dashboard');
            // Para clientes, navegar para o dashboard (onde eles veem seu suporte psicológico)
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const ClientDashboard(),
              ),
              (route) => false, // Remove todas as rotas anteriores
            );
          } else {
            debugPrint('👩‍⚕️ Navegando profissional para PatientDetailsPage');
            // Para profissionais, navegar para PatientDetailsPage
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PatientDetailsPage(
                  pacienteId: pacienteId,
                  initialTabIndex: 3, // Índice da aba de suporte psicológico
                ),
              ),
            );
          }
        }
        break;


      default:
    }
  }

  Future<void> _markAllAsRead(NotificationProvider provider) async {
    try {
      await provider.markAllAsRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todas as notificações foram marcadas como lidas'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao marcar notificações como lidas: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

}