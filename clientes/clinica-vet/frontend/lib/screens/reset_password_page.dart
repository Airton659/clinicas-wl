import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/modern_widgets.dart';
import '../utils/error_handler.dart';
import '../widgets/ygg_branding.dart';
import '../widgets/auth_wrapper.dart';

class ResetPasswordPage extends StatefulWidget {
  final String? oobCode;

  const ResetPasswordPage({super.key, this.oobCode});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _passwordReset = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _email;
  String? _errorMessage;

  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
    _verifyActionCode();
  }

  void _setupAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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
      if (mounted) {
        _fadeAnimationController.forward();
        _slideAnimationController.forward();
      }
    });
  }

  Future<void> _verifyActionCode() async {
    if (widget.oobCode == null || widget.oobCode!.isEmpty) {
      setState(() {
        _errorMessage = 'Link inválido ou expirado. Por favor, solicite um novo link de redefinição de senha.';
      });
      return;
    }

    try {
      final auth = FirebaseAuth.instance;
      final info = await auth.verifyPasswordResetCode(widget.oobCode!);
      setState(() {
        _email = info;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = ErrorHandler.getFirebaseAuthErrorMessage(e);
      });
    }
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (widget.oobCode == null || widget.oobCode!.isEmpty) {
      _showErrorSnackBar('Código de redefinição inválido');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = FirebaseAuth.instance;
      await auth.confirmPasswordReset(
        code: widget.oobCode!,
        newPassword: _passwordController.text.trim(),
      );

      if (mounted) {
        setState(() => _passwordReset = true);
        _showSuccessSnackBar('Senha redefinida com sucesso!');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showErrorSnackBar(ErrorHandler.getFirebaseAuthErrorMessage(e));
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(ErrorHandler.getGenericErrorMessage(e));
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
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

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _passwordReset
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: AppTheme.primaryBlue),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: const Text(
          'Redefinir Senha',
          style: TextStyle(
            color: AppTheme.primaryBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
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
                    if (_errorMessage != null) ...[
                      _buildErrorContent(),
                      const SizedBox(height: 24),
                      _buildBackToLoginButton(),
                    ] else if (!_passwordReset) ...[
                      if (_email != null) ...[
                        _buildForm(),
                        const SizedBox(height: 24),
                        _buildResetButton(),
                      ] else ...[
                        _buildLoadingContent(),
                      ]
                    ] else ...[
                      _buildSuccessContent(),
                      const SizedBox(height: 24),
                      _buildLoginButton(),
                    ],
                    const SizedBox(height: 32),
                    const Center(child: YggBranding(fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    IconData icon = Icons.lock_reset_rounded;
    String title = 'Redefinir Senha';
    String subtitle = 'Digite sua nova senha abaixo.';

    if (_errorMessage != null) {
      icon = Icons.error_outline_rounded;
      title = 'Link Inválido';
      subtitle = _errorMessage!;
    } else if (_passwordReset) {
      icon = Icons.check_circle_outline_rounded;
      title = 'Senha Redefinida!';
      subtitle = 'Sua senha foi atualizada com sucesso.';
    } else if (_email == null) {
      icon = Icons.hourglass_empty_rounded;
      title = 'Verificando...';
      subtitle = 'Aguarde enquanto verificamos seu link.';
    }

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _errorMessage != null
                ? AppTheme.errorRed.withOpacity(0.1)
                : _passwordReset
                    ? AppTheme.successGreen.withOpacity(0.1)
                    : AppTheme.primaryBlue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 40,
            color: _errorMessage != null
                ? AppTheme.errorRed
                : _passwordReset
                    ? AppTheme.successGreen
                    : AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.neutralGray800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.neutralGray500,
          ),
          textAlign: TextAlign.center,
        ),
        if (_email != null && !_passwordReset && _errorMessage == null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _email!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingContent() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppTheme.neutralGray200),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorContent() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.errorRed.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: AppTheme.errorRed,
          ),
          const SizedBox(height: 16),
          Text(
            'Possíveis motivos:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.neutralGray700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• O link já foi utilizado\n• O link expirou\n• O link foi copiado incorretamente',
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

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppTheme.neutralGray200),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ModernTextField(
              label: 'Nova Senha',
              hint: 'Digite sua nova senha',
              prefixIcon: Icons.lock_outline,
              controller: _passwordController,
              obscureText: _obscurePassword,
              suffixIcon: _obscurePassword ? Icons.visibility_off : Icons.visibility,
              onSuffixPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Por favor, insira uma senha';
                }
                if (value!.length < 6) {
                  return 'A senha deve ter pelo menos 6 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ModernTextField(
              label: 'Confirmar Nova Senha',
              hint: 'Digite novamente sua nova senha',
              prefixIcon: Icons.lock_outline,
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              suffixIcon: _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
              onSuffixPressed: () {
                setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
              },
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Por favor, confirme sua senha';
                }
                if (value != _passwordController.text) {
                  return 'As senhas não coincidem';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return GradientButton(
      text: 'Redefinir Senha',
      onPressed: _resetPassword,
      isLoading: _isLoading,
      icon: Icons.check_rounded,
      height: 56,
    );
  }

  Widget _buildSuccessContent() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.successGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.successGreen.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: AppTheme.successGreen,
          ),
          const SizedBox(height: 16),
          Text(
            'Agora você pode fazer login com sua nova senha.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.neutralGray600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return GradientButton(
      text: 'Ir para Login',
      onPressed: _goToLogin,
      icon: Icons.login_rounded,
      height: 56,
    );
  }

  Widget _buildBackToLoginButton() {
    return OutlinedButton.icon(
      onPressed: _goToLogin,
      icon: const Icon(Icons.arrow_back_rounded),
      label: const Text('Voltar ao Login'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryBlue,
        side: const BorderSide(color: AppTheme.primaryBlue),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
