// lib/screens/create_report_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../api/api_service.dart';
import '../models/usuario.dart';
import '../models/relatorio_medico.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/modern_widgets.dart';
import '../utils/date_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CreateReportPage extends StatefulWidget {
  final String pacienteId;
  final String pacienteNome;

  const CreateReportPage({
    super.key,
    required this.pacienteId,
    required this.pacienteNome,
  });

  @override
  State<CreateReportPage> createState() => _CreateReportPageState();
}

class _CreateReportPageState extends State<CreateReportPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Future<List<Usuario>>? _medicosFuture;
  Usuario? _selectedMedico;
  final List<XFile> _selectedImages = [];
  bool _isCreatingReport = false;
  final TextEditingController _anotacoesController = TextEditingController();
  
  // Dados reais do paciente
  String? _pacienteEndereco;
  String? _pacienteTelefone;
  String? _pacienteIdade;
  String? _pacienteSexo;
  String? _pacienteEstadoCivil;
  String? _pacienteProfissao;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadMedicos();
    _loadPatientData();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _anotacoesController.dispose();
    super.dispose();
  }

  void _loadMedicos() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _medicosFuture = apiService.getMedicos().then((medicos) {
        for (var medico in medicos) {
        }
        return medicos;
      }).catchError((error) {
        // Se for erro 422, provavelmente não há médicos cadastrados
        if (error.toString().contains('Dados incompletos ou inválidos')) {
          return <Usuario>[]; // Retorna lista vazia em vez de erro
        }
        throw error; // Re-throw outros erros
      });
    });
  }

  Future<void> _loadPatientData() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      
      // Buscar lista de pacientes para encontrar os dados completos
      final pacientes = await apiService.getPacientes();
      final paciente = pacientes.firstWhere(
        (p) => p.id == widget.pacienteId,
        orElse: () => throw Exception('Paciente não encontrado na lista'),
      );
      
      setState(() {
        // Extrair dados reais do paciente
        _pacienteTelefone = paciente.telefone ?? 'Não informado';
        
        // Processar endereço (pode ser um Map)
        if (paciente.endereco != null && paciente.endereco!.isNotEmpty) {
          // Se for um Map, tentar extrair os dados principais
          final endereco = paciente.endereco!;
          final rua = endereco['rua'] ?? endereco['logradouro'] ?? '';
          final numero = endereco['numero'] ?? '';
          final cidade = endereco['cidade'] ?? '';
          
          if (rua.isNotEmpty || numero.isNotEmpty || cidade.isNotEmpty) {
            _pacienteEndereco = [rua, numero, cidade].where((s) => s.isNotEmpty).join(', ');
          } else {
            _pacienteEndereco = 'Não informado';
          }
        } else {
          _pacienteEndereco = 'Não informado';
        }
        
        // Usar função utilitária para calcular idade
        _pacienteIdade = formatarIdade(paciente.dataNascimento);
        
        // Extrair novos dados pessoais
        _pacienteSexo = paciente.sexo ?? 'Não informado';
        _pacienteEstadoCivil = paciente.estadoCivil ?? 'Não informado';
        _pacienteProfissao = paciente.profissao ?? 'Não informado';
      });
      
    } catch (e) {
      setState(() {
        _pacienteEndereco = 'Erro ao carregar';
        _pacienteTelefone = 'Erro ao carregar';
        _pacienteIdade = 'Erro ao carregar';
        _pacienteSexo = 'Erro ao carregar';
        _pacienteEstadoCivil = 'Erro ao carregar';
        _pacienteProfissao = 'Erro ao carregar';
      });
    }
  }

  Future<void> _selectImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
      }
    } catch (e) {
      _showErrorMessage('Erro ao selecionar imagem: $e');
    }
  }

  Future<void> _selectMultipleImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      setState(() {
        _selectedImages.addAll(images);
      });
    } catch (e) {
      _showErrorMessage('Erro ao selecionar imagens: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.neutralGray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Selecionar Fotos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildImageSourceOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Câmera',
                      onTap: () {
                        Navigator.pop(context);
                        _selectImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildImageSourceOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Galeria',
                      onTap: () {
                        Navigator.pop(context);
                        _selectMultipleImages();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryBlue, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createReport() async {

    if (_selectedMedico == null) {
      _showErrorMessage('Por favor, selecione um médico.');
      return;
    }

    // Validação obrigatória do campo de anotações
    if (_anotacoesController.text.trim().isEmpty) {
      _showErrorMessage('Por favor, adicione observações e anotações sobre o paciente.');
      return;
    }

    setState(() {
      _isCreatingReport = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      
      // Criar o relatório
      final RelatorioMedico relatorio = await apiService.createRelatorio(
        widget.pacienteId,
        _selectedMedico!.id ?? '',
        conteudo: _anotacoesController.text.trim(),
      );
      
      if (_selectedImages.isNotEmpty) {
        await apiService.addRelatorioFotos(relatorio.id, _selectedImages);
      }

      if (mounted) {
        _showSuccessMessage('Relatório criado e enviado com sucesso!');
        Navigator.pop(context, true); // Retorna true para indicar sucesso
      }
    } catch (e, stackTrace) {
      
      if (mounted) {
        _showErrorMessage('Erro ao criar relatório: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingReport = false;
        });
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
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

  void _showErrorMessage(String message) {
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
        title: const Text('Criar Relatório Médico'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPatientBasicInfoCard(),
                const SizedBox(height: 24),
                _buildMedicoSelectionCard(),
                const SizedBox(height: 24),
                _buildAnotacoesCard(),
                const SizedBox(height: 24),
                _buildPhotosCard(),
                const SizedBox(height: 32),
                _buildCreateButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientBasicInfoCard() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Dados do Paciente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Nome', widget.pacienteNome),
          _buildInfoRow('Idade', _pacienteIdade ?? 'Carregando...'),
          _buildInfoRow('Sexo', _pacienteSexo ?? 'Carregando...'),
          _buildInfoRow('Estado Civil', _pacienteEstadoCivil ?? 'Carregando...'),
          _buildInfoRow('Profissão', _pacienteProfissao ?? 'Carregando...'),
          _buildInfoRow('Endereço', _pacienteEndereco ?? 'Carregando...'),  
          _buildInfoRow('Telefone', _pacienteTelefone ?? 'Carregando...')
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.neutralGray600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.neutralGray800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnotacoesCard() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: AppTheme.successGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  const Text(
                    'Anotações do Relatório',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '*',
                    style: TextStyle(
                      color: AppTheme.errorRed,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _anotacoesController,
            maxLines: 6,
            enableInteractiveSelection: true,
            decoration: InputDecoration(
              hintText: '* Digite suas observações e anotações sobre o paciente (obrigatório)...',
              hintStyle: TextStyle(
                color: AppTheme.neutralGray500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.neutralGray300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.accentTeal,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Escreva suas observações, diagnósticos e recomendações de forma livre.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.accentTeal,
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

  Widget _buildMedicoSelectionCard() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  color: AppTheme.successGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Médico Responsável',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Usuario>>(
            future: _medicosFuture,
            builder: (context, snapshot) {
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              if (snapshot.hasError) {
                return Column(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.errorRed,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Erro ao carregar médicos',
                      style: TextStyle(
                        color: AppTheme.neutralGray600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Erro: ${snapshot.error}',
                      style: TextStyle(
                        color: AppTheme.errorRed,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _loadMedicos,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar Novamente'),
                    ),
                  ],
                );
              }
              
              final medicos = snapshot.data ?? [];
              
              if (medicos.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.warningOrange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Nenhum médico cadastrado no sistema.',
                          style: TextStyle(
                            color: AppTheme.warningOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return Column(
                children: medicos.map((medico) => _buildMedicoOption(medico)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMedicoOption(Usuario medico) {
    final isSelected = _selectedMedico?.id == medico.id;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMedico = medico;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
              : AppTheme.neutralGray50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? AppTheme.primaryBlue
                : AppTheme.neutralGray200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.neutralGray400,
                  width: 2,
                ),
                shape: BoxShape.circle,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dr. ${medico.nome}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppTheme.primaryBlue : AppTheme.neutralGray800,
                    ),
                  ),
                  if (medico.email != null)
                    Text(
                      medico.email!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.neutralGray600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosCard() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: AppTheme.warningOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Fotos (Opcional)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_selectedImages.isNotEmpty)
                Text(
                  '${_selectedImages.length} foto${_selectedImages.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.neutralGray600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedImages.isEmpty) ...[
            GestureDetector(
              onTap: _showImageSourceBottomSheet,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.neutralGray100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.neutralGray300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_rounded,
                      color: AppTheme.neutralGray500,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tocar para adicionar fotos',
                      style: TextStyle(
                        color: AppTheme.neutralGray600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _selectedImages.length + 1,
              itemBuilder: (context, index) {
                if (index == _selectedImages.length) {
                  return GestureDetector(
                    onTap: _showImageSourceBottomSheet,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.neutralGray100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.neutralGray300),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: AppTheme.neutralGray500,
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Adicionar',
                            style: TextStyle(
                              color: AppTheme.neutralGray600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                return _buildImagePreview(index);
              },
            ),
          ],
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.accentTeal,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'As fotos serão anexadas ao relatório para análise médica.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.accentTeal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePreview(int index) {
  final imageFile = _selectedImages[index];

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.neutralGray300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            // A MÁGICA ACONTECE AQUI
            child: kIsWeb
                ? Image.network( // Usa Image.network para a Web (funciona com blob URLs)
                    imageFile.path,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  )
                : Image.file( // Mantém Image.file para Android e iOS
                    File(imageFile.path),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppTheme.errorRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    final canCreate = _selectedMedico != null && !_isCreatingReport;
    
    return ElevatedButton.icon(
      onPressed: canCreate ? _createReport : null,
      icon: _isCreatingReport
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send_rounded),
      label: const Text('Enviar Relatório'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}