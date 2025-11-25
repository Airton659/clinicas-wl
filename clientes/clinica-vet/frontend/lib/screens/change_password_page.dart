// lib/screens/change_password_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/modern_widgets.dart';
import '../utils/error_handler.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitChangePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;

    try {
      await authService.changePassword(currentPassword, newPassword);
      
      if (mounted) {
        _showFeedbackSnackBar('Senha alterada com sucesso!', isError: false);
        Navigator.of(context).pop();
      }

    } on FirebaseAuthException catch (e) {
      _showFeedbackSnackBar(ErrorHandler.getFirebaseAuthErrorMessage(e), isError: true);
    } catch (e) {
      _showFeedbackSnackBar(ErrorHandler.getGenericErrorMessage(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showFeedbackSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alterar Senha'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ModernCard(
                child: Column(
                  children: [
                    ModernTextField(
                      controller: _currentPasswordController,
                      label: 'Senha Atual *',
                      prefixIcon: Icons.lock_clock_rounded,
                      obscureText: _obscureCurrent,
                      suffixIcon: _obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      onSuffixPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      validator: (value) => (value?.isEmpty ?? true) ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    ModernTextField(
                      controller: _newPasswordController,
                      label: 'Nova Senha *',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscureNew,
                      suffixIcon: _obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      onSuffixPressed: () => setState(() => _obscureNew = !_obscureNew),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Campo obrigatório';
                        if (value!.length < 6) return 'A senha deve ter no mínimo 6 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ModernTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirmar Nova Senha *',
                      prefixIcon: Icons.lock_rounded,
                      obscureText: _obscureConfirm,
                      suffixIcon: _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      onSuffixPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Campo obrigatório';
                        if (value != _newPasswordController.text) return 'As senhas não coincidem';
                        return null;
                      },
                    ),
                  ],
                )
              ),
              const SizedBox(height: 32),
              GradientButton(
                text: 'Salvar Alterações',
                onPressed: _submitChangePassword,
                isLoading: _isLoading,
                icon: Icons.save_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}