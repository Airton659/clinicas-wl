import 'package:flutter/material.dart';
import '../models/negocio.dart';
import '../services/super_admin_service.dart';

/// Tela para editar terminologia customizada de um negócio
/// Disponível apenas para Super Admins
class TerminologyEditorPage extends StatefulWidget {
  final Negocio negocio;
  final SuperAdminService superAdminService;

  const TerminologyEditorPage({
    Key? key,
    required this.negocio,
    required this.superAdminService,
  }) : super(key: key);

  @override
  State<TerminologyEditorPage> createState() => _TerminologyEditorPageState();
}

class _TerminologyEditorPageState extends State<TerminologyEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _justificativaController = TextEditingController();

  late TextEditingController _patientController;
  late TextEditingController _consultationController;
  late TextEditingController _anamneseController;
  late TextEditingController _teamController;
  late TextEditingController _examController;
  late TextEditingController _medicationController;
  late TextEditingController _guidelineController;
  late TextEditingController _diaryController;
  late TextEditingController _medicalReportController;

  bool _loading = true;
  bool _saving = false;
  CustomTerminology? _originalTerminology;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadTerminology();
  }

  void _initControllers() {
    _patientController = TextEditingController();
    _consultationController = TextEditingController();
    _anamneseController = TextEditingController();
    _teamController = TextEditingController();
    _examController = TextEditingController();
    _medicationController = TextEditingController();
    _guidelineController = TextEditingController();
    _diaryController = TextEditingController();
    _medicalReportController = TextEditingController();
  }

  @override
  void dispose() {
    _patientController.dispose();
    _consultationController.dispose();
    _anamneseController.dispose();
    _teamController.dispose();
    _examController.dispose();
    _medicationController.dispose();
    _guidelineController.dispose();
    _diaryController.dispose();
    _medicalReportController.dispose();
    _justificativaController.dispose();
    super.dispose();
  }

  Future<void> _loadTerminology() async {
    setState(() => _loading = true);

    try {
      final terminology =
          await widget.superAdminService.getTerminology(widget.negocio.id);

      setState(() {
        _originalTerminology = terminology;
        _patientController.text = terminology.patient;
        _consultationController.text = terminology.consultation;
        _anamneseController.text = terminology.anamnese;
        _teamController.text = terminology.team;
        _examController.text = terminology.exam;
        _medicationController.text = terminology.medication;
        _guidelineController.text = terminology.guideline;
        _diaryController.text = terminology.diary;
        _medicalReportController.text = terminology.medicalReport;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar terminologia: $e')),
        );
      }
    }
  }

  Future<void> _saveTerminology() async {
    if (!_formKey.currentState!.validate()) return;

    // Solicitar justificativa
    final justificativa = await _showJustificativaDialog();
    if (justificativa == null || justificativa.trim().length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Justificativa é obrigatória (mínimo 20 caracteres)'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final newTerminology = CustomTerminology(
        patient: _patientController.text.trim(),
        consultation: _consultationController.text.trim(),
        anamnese: _anamneseController.text.trim(),
        team: _teamController.text.trim(),
        exam: _examController.text.trim(),
        medication: _medicationController.text.trim(),
        guideline: _guidelineController.text.trim(),
        diary: _diaryController.text.trim(),
        medicalReport: _medicalReportController.text.trim(),
      );

      await widget.superAdminService.updateTerminologyWithAudit(
        negocioId: widget.negocio.id,
        terminology: newTerminology,
        justificativa: justificativa,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terminologia atualizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetar Terminologia'),
        content: const Text(
          'Isso irá restaurar todos os termos para os valores padrão. '
          'Esta ação requer justificativa. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Resetar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final justificativa = await _showJustificativaDialog();
    if (justificativa == null || justificativa.trim().length < 20) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Justificativa é obrigatória (mínimo 20 caracteres)'),
          ),
        );
      }
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.superAdminService.resetTerminologyWithAudit(
        negocioId: widget.negocio.id,
        justificativa: justificativa,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terminologia resetada para padrões!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadTerminology();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao resetar: $e')),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<String?> _showJustificativaDialog() async {
    _justificativaController.clear();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Justificativa Obrigatória'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Por questões de auditoria, é necessário justificar '
              'esta alteração em dados de outro negócio.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _justificativaController,
              decoration: const InputDecoration(
                labelText: 'Justificativa',
                hintText: 'Descreva o motivo desta alteração...',
                border: OutlineInputBorder(),
                helperText: 'Mínimo 20 caracteres',
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = _justificativaController.text.trim();
              if (text.length >= 20) {
                Navigator.pop(context, text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Justificativa muito curta (mín. 20 caracteres)'),
                  ),
                );
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Editar Terminologia', style: TextStyle(fontSize: 18)),
            Text(
              widget.negocio.nome,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            onPressed: _loading || _saving ? null : _resetToDefaults,
            icon: const Icon(Icons.restore),
            tooltip: 'Resetar para Padrões',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(),
      floatingActionButton: _saving
          ? const CircularProgressIndicator()
          : FloatingActionButton.extended(
              onPressed: _saveTerminology,
              icon: const Icon(Icons.save),
              label: const Text('Salvar'),
              backgroundColor: Colors.green,
            ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoBanner(),
          const SizedBox(height: 24),
          _buildTermField(
            controller: _patientController,
            label: 'Paciente',
            hint: 'Ex: Paciente, Animal, Atleta...',
            icon: Icons.person,
          ),
          _buildTermField(
            controller: _consultationController,
            label: 'Consulta',
            hint: 'Ex: Consulta, Atendimento, Sessão...',
            icon: Icons.event,
          ),
          _buildTermField(
            controller: _anamneseController,
            label: 'Anamnese',
            hint: 'Ex: Anamnese, Histórico, Avaliação...',
            icon: Icons.description,
          ),
          _buildTermField(
            controller: _teamController,
            label: 'Equipe',
            hint: 'Ex: Equipe, Staff, Time...',
            icon: Icons.group,
          ),
          _buildTermField(
            controller: _examController,
            label: 'Exame',
            hint: 'Ex: Exame, Teste, Análise...',
            icon: Icons.science,
          ),
          _buildTermField(
            controller: _medicationController,
            label: 'Medicação',
            hint: 'Ex: Medicação, Remédio, Fármaco...',
            icon: Icons.medication,
          ),
          _buildTermField(
            controller: _guidelineController,
            label: 'Orientação',
            hint: 'Ex: Orientação, Recomendação, Diretriz...',
            icon: Icons.lightbulb,
          ),
          _buildTermField(
            controller: _diaryController,
            label: 'Diário',
            hint: 'Ex: Diário, Registro, Log...',
            icon: Icons.book,
          ),
          _buildTermField(
            controller: _medicalReportController,
            label: 'Relatório Médico',
            hint: 'Ex: Relatório Médico, Laudo, Parecer...',
            icon: Icons.file_copy,
          ),
          const SizedBox(height: 80), // Espaço para FAB
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Personalize os termos usados no sistema para este negócio. '
              'Estas alterações serão auditadas.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        maxLength: 50,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Campo obrigatório';
          }
          if (value.trim().length < 2) {
            return 'Mínimo 2 caracteres';
          }
          return null;
        },
      ),
    );
  }
}
