// lib/screens/add_patient_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../api/api_service.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/modern_widgets.dart';

class AddPatientPage extends StatefulWidget {
  const AddPatientPage({super.key});

  @override
  State<AddPatientPage> createState() => _AddPatientPageState();
}

class _AddPatientPageState extends State<AddPatientPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers para dados pessoais
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _telefoneController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _consentimentoLgpd = false;

  // Animações
  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;

  // Formatadores
  final _phoneFormatter = MaskTextInputFormatter(
      mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimationController.forward();
  }

  @override
  void dispose() {
    _slideAnimationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  bool _validatePersonalData() {
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar('Nome é obrigatório');
      return false;
    }
    if (_emailController.text.trim().isEmpty ||
        !RegExp(r'\S+@\S+\.\S+').hasMatch(_emailController.text)) {
      _showErrorSnackBar('Email válido é obrigatório');
      return false;
    }
    if (_passwordController.text.length < 6) {
      _showErrorSnackBar('Senha deve ter no mínimo 6 caracteres');
      return false;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar('As senhas não coincidem');
      return false;
    }
    if (!_consentimentoLgpd) {
      _showErrorSnackBar('É necessário declarar que obteve o consentimento do paciente');
      return false;
    }
    return true;
  }

  Future<void> _savePatient() async {
    if (!_validatePersonalData()) return;

    setState(() => _isLoading = true);

    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final patientData = {
        'nome': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        if (_telefoneController.text.isNotEmpty)
          'telefone': _phoneFormatter.getUnmaskedText(),
        // Paciente inicia com consentimento pendente - será pedido no primeiro login
        'consentimento_lgpd': false,
        'data_consentimento_lgpd': null,
        'tipo_consentimento': null,
        // O campo 'endereco' foi removido daqui
      };

      final Usuario newPatient = await apiService.createPatient(patientData);

      const negocioId = "rlAB6phw0EBsBFeDyOt6";
      final currentUser = authService.currentUser;
      final userRole = currentUser?.roles?[negocioId];

      if (userRole == 'profissional') {
        final nurseProfileId = currentUser?.profissional_id;
        final newPatientId = newPatient.id;

        if (nurseProfileId != null && newPatientId != null) {
          await apiService.linkPatientToNurse(newPatientId, nurseProfileId);
        }
      }

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao cadastrar paciente: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Paciente Cadastrado!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.neutralGray800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'O paciente ${_nameController.text.trim()} foi cadastrado com sucesso.',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.neutralGray600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GradientButton(
              text: 'Continuar',
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(true);
              },
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
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
      backgroundColor: AppTheme.neutralGray50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.neutralGray200),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: const Text(
          'Novo Paciente',
          style: TextStyle(
            color: AppTheme.neutralGray800,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: _buildPersonalDataStep(),
              ),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalDataStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dados Pessoais',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.neutralGray800,
                          ),
                        ),
                        Text(
                          'Informações básicas do paciente',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.neutralGray500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ModernTextField(
                  label: 'Nome Completo *',
                  hint: 'Digite o nome completo',
                  prefixIcon: Icons.person_outline_rounded,
                  controller: _nameController,
                ),
                const SizedBox(height: 16),
                ModernTextField(
                  label: 'Email *',
                  hint: 'Digite o email',
                  prefixIcon: Icons.email_outlined,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                ModernTextField(
                  label: 'Senha *',
                  hint: 'Digite a senha (mínimo 6 caracteres)',
                  prefixIcon: Icons.lock_outlined,
                  suffixIcon: _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  onSuffixPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                ),
                const SizedBox(height: 16),
                ModernTextField(
                  label: 'Confirmar Senha *',
                  hint: 'Digite a senha novamente',
                  prefixIcon: Icons.lock_outlined,
                  suffixIcon: _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  onSuffixPressed: () {
                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                  },
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                ),
                const SizedBox(height: 16),
                ModernTextField(
                  label: 'Telefone (Opcional)',
                  hint: '(11) 99999-9999',
                  prefixIcon: Icons.phone_outlined,
                  controller: _telefoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_phoneFormatter],
                ),
                const SizedBox(height: 24),
                _buildLgpdConsentSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLgpdConsentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.neutralGray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neutralGray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security_rounded,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Proteção de Dados (LGPD)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutralGray800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Antes de cadastrar este paciente no sistema, você deve ter obtido o consentimento físico do paciente (ou responsável legal) através de um Termo de Consentimento para Tratamento de Dados Pessoais e Sensíveis, conforme a LGPD.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.neutralGray600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
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
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _consentimentoLgpd ? AppTheme.primaryBlue : Colors.transparent,
                    border: Border.all(
                      color: _consentimentoLgpd ? AppTheme.primaryBlue : AppTheme.neutralGray400,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _consentimentoLgpd
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.neutralGray700,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Declaro que ',
                        ),
                        TextSpan(
                          text: 'obtive o consentimento explícito do paciente',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const TextSpan(
                          text: ' (ou de seu responsável legal) para a coleta e o tratamento de seus dados pessoais e de saúde, conforme a Política de Privacidade da empresa, e o informei que seus dados serão gerenciados através desta plataforma.',
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

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.neutralGray200, width: 1),
        ),
      ),
      child: SafeArea(
        child: GradientButton(
          text: 'Cadastrar Paciente',
          onPressed: _savePatient,
          isLoading: _isLoading,
          icon: Icons.person_add_rounded,
        ),
      ),
    );
  }
}