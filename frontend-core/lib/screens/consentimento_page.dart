// lib/screens/consentimento_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_service.dart';
import '../services/auth_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/modern_widgets.dart';

class ConsentimentoPage extends StatefulWidget {
  const ConsentimentoPage({super.key});

  @override
  State<ConsentimentoPage> createState() => _ConsentimentoPageState();
}

class _ConsentimentoPageState extends State<ConsentimentoPage>
    with TickerProviderStateMixin {
  bool _consentimentoLgpd = false;
  bool _isLoading = false;

  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
  }

  void _setupAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _fadeAnimationController.forward();
      _slideAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    super.dispose();
  }

  Future<void> _saveConsent() async {
    
    if (!_consentimentoLgpd) {
      _showErrorSnackBar('É necessário aceitar o consentimento para continuar');
      return;
    }

    setState(() => _isLoading = true);

    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final currentUser = authService.currentUser;
      
      if (currentUser?.id != null) {
        await apiService.updateMyConsent(
          _consentimentoLgpd,
          DateTime.now(),
          'digital',
        );

        await authService.refreshCurrentUser();
        
        if (mounted) {
          // AuthWrapper vai detectar que consentimento_lgpd = true e redirecionar automaticamente
        }
      } else {
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao salvar consentimento: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
    
  }

  void _showErrorSnackBar(String message) {
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBlue,
              AppTheme.accentTeal,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildConsentForm(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          ),
          child: const Icon(
            Icons.security_rounded,
            color: Colors.white,
            size: 60,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Proteção de Dados',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Lei Geral de Proteção de Dados (LGPD)',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildConsentForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Consentimento Obrigatório',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neutralGray800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Este sistema coleta e processa dados pessoais sensíveis relacionados à saúde. Para continuar utilizando o sistema, você precisa autorizar o tratamento desses dados.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.neutralGray600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.neutralGray50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.neutralGray200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dados coletados:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.neutralGray800,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDataItem('• Informações pessoais dos pacientes'),
                _buildDataItem('• Histórico de cuidados médicos'),
                _buildDataItem('• Registros diários de enfermagem'),
                _buildDataItem('• Orientações de cuidados'),
                const SizedBox(height: 12),
                const Text(
                  'Finalidade:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.neutralGray800,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDataItem('• Prestação de serviços de enfermagem'),
                _buildDataItem('• Acompanhamento de pacientes'),
                _buildDataItem('• Gestão de cuidados de saúde'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              setState(() {
                _consentimentoLgpd = !_consentimentoLgpd;
              });
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _consentimentoLgpd ? AppTheme.primaryBlue : Colors.transparent,
                    border: Border.all(
                      color: _consentimentoLgpd ? AppTheme.primaryBlue : AppTheme.neutralGray400,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _consentimentoLgpd
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.neutralGray700,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Eu ',
                        ),
                        TextSpan(
                          text: 'autorizo e consinto',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const TextSpan(
                          text: ' com o tratamento dos meus dados pessoais e dados pessoais sensíveis relacionados à saúde para as finalidades descritas acima, conforme a Lei Geral de Proteção de Dados (LGPD).',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppTheme.neutralGray600,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        GradientButton(
          text: 'Aceitar e Continuar',
          onPressed: _saveConsent,
          isLoading: _isLoading,
          icon: Icons.check_rounded,
          height: 56,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sem este consentimento, você não poderá utilizar o sistema.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}