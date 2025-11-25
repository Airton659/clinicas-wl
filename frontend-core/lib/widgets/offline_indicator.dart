// lib/widgets/offline_indicator.dart

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/theme/app_theme.dart';
import '../services/cache_manager.dart';

class OfflineIndicator extends StatefulWidget {
  final Widget child;
  final bool showAlways;

  const OfflineIndicator({
    super.key,
    required this.child,
    this.showAlways = false,
  });

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator>
    with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  bool _showIndicator = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _checkConnectivity();
    _listenToConnectivity();
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

  void _checkConnectivity() async {
    try {
      final cacheManager = CacheManager.instance;
      final isOnline = await cacheManager.isOnline();
      _updateConnectionStatus(isOnline);
    } catch (e) {
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        // MUDANÇA AQUI: Agora verifica se a LISTA contém 'none'
        final isOnline = !connectivityResult.contains(ConnectivityResult.none);
        _updateConnectionStatus(isOnline);
      } catch (e2) {
        _updateConnectionStatus(true);
      }
    }
  }

  void _listenToConnectivity() {
    try {
      // MUDANÇA AQUI: O resultado agora é uma LISTA
      Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
        final isOnline = !result.contains(ConnectivityResult.none);
        _updateConnectionStatus(isOnline);
      });
    } catch (e) {
      _startPeriodicCheck();
    }
  }

  void _startPeriodicCheck() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _checkConnectivity();
        _startPeriodicCheck();
      }
    });
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

class ConnectionAwareFutureBuilder<T> extends StatelessWidget {
  final Future<T>? future;
  final Future<T>? offlineFallback;
  final Widget Function(BuildContext context, AsyncSnapshot<T> snapshot) builder;

  const ConnectionAwareFutureBuilder({
    super.key,
    this.future,
    this.offlineFallback,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConnectivityResult>>( // MUDANÇA AQUI
      future: _checkConnectivitySafely(),
      builder: (context, connectivitySnapshot) {
        if (connectivitySnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final isOnline = connectivitySnapshot.data != null &&
            !connectivitySnapshot.data!.contains(ConnectivityResult.none); // MUDANÇA AQUI
        final activeFuture = isOnline ? future : (offlineFallback ?? future);

        return FutureBuilder<T>(
          future: activeFuture,
          builder: builder,
        );
      },
    );
  }

  Future<List<ConnectivityResult>> _checkConnectivitySafely() async { // MUDANÇA AQUI
    try {
      return await Connectivity().checkConnectivity();
    } catch (e) {
      return [ConnectivityResult.none]; // Retorna uma lista indicando offline
    }
  }
}

class OfflineBadge extends StatelessWidget {
  final Widget child;
  final bool showWhenOnline;

  const OfflineBadge({
    super.key,
    required this.child,
    this.showWhenOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConnectivityResult>>( // MUDANÇA AQUI
      future: _checkConnectivitySafely(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return child;
        }

        final isOffline = snapshot.data != null && snapshot.data!.contains(ConnectivityResult.none); // MUDANÇA AQUI

        if (!isOffline && !showWhenOnline) {
          return child;
        }

        return Stack(
          children: [
            child,
            if (isOffline)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'OFFLINE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<List<ConnectivityResult>> _checkConnectivitySafely() async { // MUDANÇA AQUI
    try {
      return await Connectivity().checkConnectivity();
    } catch (e) {
      return [ConnectivityResult.none];
    }
  }
}