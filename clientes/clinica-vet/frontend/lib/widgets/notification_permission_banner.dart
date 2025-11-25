// lib/widgets/notification_permission_banner.dart

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationPermissionBanner extends StatefulWidget {
  const NotificationPermissionBanner({super.key});

  @override
  State<NotificationPermissionBanner> createState() => _NotificationPermissionBannerState();
}

class _NotificationPermissionBannerState extends State<NotificationPermissionBanner> {
  bool _showBanner = false;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();

      if (mounted) {
        setState(() {
          _showBanner = settings.authorizationStatus == AuthorizationStatus.denied ||
              settings.authorizationStatus == AuthorizationStatus.notDetermined;
        });
      }
    } catch (e) {
      debugPrint('Erro ao verificar permissão: $e');
    }
  }

  Future<void> _requestPermission() async {
    if (_isRequesting) return;

    setState(() {
      _isRequesting = true;
    });

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (mounted) {
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Notificações ativadas com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _showBanner = false;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('❌ Permissão negada. Ative nas configurações do navegador.'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'COMO FAZER',
                textColor: Colors.white,
                onPressed: () {
                  _showInstructions();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao solicitar permissão: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Como ativar notificações'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chrome/Edge:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('1. Clique no ícone de cadeado (🔒) na barra de endereço'),
              const Text('2. Procure por "Notificações"'),
              const Text('3. Selecione "Permitir"'),
              const Text('4. Recarregue a página'),
              const SizedBox(height: 16),
              const Text(
                'Safari (Mobile):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('1. Vá em Configurações do iOS'),
              const Text('2. Navegador > Notificações'),
              const Text('3. Encontre este site e ative'),
              const SizedBox(height: 16),
              const Text(
                'Depois de ativar, recarregue a página.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDI'),
          ),
        ],
      ),
    );
  }

  void _dismiss() {
    setState(() {
      _showBanner = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showBanner) return const SizedBox.shrink();

    return Material(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: Colors.blue.shade50,
        child: Row(
          children: [
            const Icon(Icons.notifications_off, color: Colors.blue),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ative as notificações',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Receba alertas importantes em tempo real',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _isRequesting ? null : _requestPermission,
              child: _isRequesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('ATIVAR'),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: _dismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
