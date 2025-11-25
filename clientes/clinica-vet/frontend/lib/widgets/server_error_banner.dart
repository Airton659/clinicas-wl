import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:analicegrubert/services/auth_service.dart';

class ServerErrorBanner extends StatelessWidget {
  final Widget child;

  const ServerErrorBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        if (!authService.hasServerError) {
          return child;
        }

        return Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: Colors.orange.shade800,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Problema no servidor',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Usando dados temporários. Algumas funcionalidades podem estar limitadas.',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}