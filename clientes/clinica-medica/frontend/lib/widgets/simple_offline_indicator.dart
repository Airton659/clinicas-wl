// lib/widgets/simple_offline_indicator.dart

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Indicador de conectividade simplificado que não depende de plugins externos
/// Use este se houver problemas com connectivity_plus
class SimpleOfflineIndicator extends StatefulWidget {
  final Widget child;
  final bool showAlways;
  
  const SimpleOfflineIndicator({
    super.key,
    required this.child,
    this.showAlways = false,
  });
  
  @override
  State<SimpleOfflineIndicator> createState() => _SimpleOfflineIndicatorState();
}

class _SimpleOfflineIndicatorState extends State<SimpleOfflineIndicator>
    with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  bool _showIndicator = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    _setupAnimation();
    // Assume online por padrão - sem verificação de conectividade
    _updateConnectionStatus(true);
  }
  
  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }
  
  void _updateConnectionStatus(bool isOnline) {
    if (!mounted) return;
    
    setState(() {
      _isOnline = isOnline;
      _showIndicator = !isOnline || widget.showAlways;
    });
    
    if (_showIndicator) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showIndicator)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildIndicatorBanner(),
            ),
          ),
      ],
    );
  }
  
  Widget _buildIndicatorBanner() {
    final isOffline = !_isOnline;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isOffline ? AppTheme.errorRed : AppTheme.successGreen,
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              isOffline 
                ? 'Modo Offline - Dados do cache local'
                : 'Conectado - Dados atualizados',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isOffline) ...[ 
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'OFFLINE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}