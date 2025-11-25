// lib/screens/anamnese_form_page.dart

import 'package:analicegrubert/api/api_service.dart';
import 'package:analicegrubert/core/theme/app_theme.dart';
import 'package:analicegrubert/core/widgets/modern_widgets.dart';
import 'package:analicegrubert/models/anamnese.dart';
import 'package:analicegrubert/services/auth_service.dart';
import 'package:analicegrubert/utils/date_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AnamneseFormPage extends StatefulWidget {
  final String pacienteId;
  final String pacienteNome;
  final Anamnese? anamnese;
  final bool isReadOnly;

  const AnamneseFormPage({
    super.key,
    required this.pacienteId,
    required this.pacienteNome,
    this.anamnese,
    this.isReadOnly = false,
  });

  bool get isEditing => anamnese != null;

  @override
  State<AnamneseFormPage> createState() => _AnamneseFormPageState();
}

class _AnamneseFormPageState extends State<AnamneseFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers para todos os campos
  final _idadeController = TextEditingController();
  String? _sexo;
  final _estadoCivilController = TextEditingController();
  final _profissaoController = TextEditingController();
  final _queixaPrincipalController = TextEditingController();
  final _historiaDoencaAtualController = TextEditingController();
  final _cirurgiasAnterioresController = TextEditingController();
  final _alergiasController = TextEditingController();
  final _medicamentosUsoContinuoController = TextEditingController();
  final _historiaFamiliarController = TextEditingController();
  bool _hasHAS = false;
  bool _hasDM = false;
  bool _hasCardiopatias = false;
  bool _hasAsmaDPOC = false;
  final _outrasDoencasController = TextEditingController();
  bool _temTabagismo = false;
  bool _temEtilismo = false;
  bool _temSedentarismo = false;
  final _outrosHabitosController = TextEditingController();
  final _pressaoArterialController = TextEditingController();
  final _fcController = TextEditingController();
  final _frController = TextEditingController();
  final _tempController = TextEditingController();
  final _spo2Controller = TextEditingController();
  String? _nivelConsciencia;
  final _estadoNutricionalController = TextEditingController();
  final _peleMucosasController = TextEditingController();
  final _sistemaRespiratorioController = TextEditingController();
  final _sistemaCardiovascularController = TextEditingController();
  final _abdomeController = TextEditingController();
  final _eliminacoesController = TextEditingController();
  final _drenosSondasCateteresController = TextEditingController();
  final _apoioFamiliarController = TextEditingController();
  final _necessidadesEmocionaisController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadPatientData();
    if (widget.isEditing && widget.anamnese != null) {
      _populateForm(widget.anamnese!);
    }
  }

  Future<void> _loadPatientData() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final pacientes = await apiService.getPacientes();
      final paciente = pacientes.firstWhere(
        (p) => p.id == widget.pacienteId,
        orElse: () => throw Exception('Paciente não encontrado'),
      );
      
      setState(() {
        // Preencher dados pessoais automaticamente do modelo Paciente
        if (paciente.dataNascimento != null) {
          final idade = calcularIdade(paciente.dataNascimento);
          _idadeController.text = idade?.toString() ?? '';
        }
        _sexo = paciente.sexo;
        _estadoCivilController.text = paciente.estadoCivil ?? '';
        _profissaoController.text = paciente.profissao ?? '';
      });
      
    } catch (e) {
      // Não fazer nada, deixar campos vazios para preenchimento manual
    }
  }

  void _populateForm(Anamnese data) {
    // NOTA: Dados pessoais (idade, sexo, estado civil, profissão) 
    // agora vêm do modelo Paciente e não devem ser sobrescritos
    // Apenas preencher se os campos estiverem vazios (fallback)
    if (_idadeController.text.isEmpty) {
      _idadeController.text = data.idade?.toString() ?? '';
    }
    if (_sexo == null) {
      _sexo = data.sexo;
    }
    if (_estadoCivilController.text.isEmpty) {
      _estadoCivilController.text = data.estadoCivil ?? '';
    }
    if (_profissaoController.text.isEmpty) {
      _profissaoController.text = data.profissao ?? '';
    }
    _queixaPrincipalController.text = data.queixaPrincipal ?? '';
    _historiaDoencaAtualController.text = data.historicoDoencaAtual ?? '';

    if (data.antecedentesPessoais != null) {
      final ap = data.antecedentesPessoais!;
      
      _hasHAS = ap.hasHAS;
      _hasDM = ap.hasDM;
      _hasCardiopatias = ap.hasCardiopatias;
      _hasAsmaDPOC = ap.hasAsmaDPOC;
      _outrasDoencasController.text = ap.outrasDoencasCronicas ?? '';
      _cirurgiasAnterioresController.text = ap.cirurgiasAnteriores ?? '';
      _alergiasController.text = ap.alergias ?? '';
      _medicamentosUsoContinuoController.text = ap.medicamentosUsoContinuo ?? '';
      _temTabagismo = ap.temTabagismo;
      _temEtilismo = ap.temEtilismo;
      _temSedentarismo = ap.temSedentarismo;
      _outrosHabitosController.text = ap.outrosHabitos ?? '';
    }
    _historiaFamiliarController.text = data.historiaFamiliar ?? '';
    
    if (data.sinaisVitais != null) {
      final sv = data.sinaisVitais!;
      _pressaoArterialController.text = sv.pressaoArterial ?? '';
      _fcController.text = sv.frequenciaCardiaca?.toString() ?? '';
      _frController.text = sv.frequenciaRespiratoria?.toString() ?? '';
      _tempController.text = sv.temperatura?.toString() ?? '';
      _spo2Controller.text = sv.saturacaoO2?.toString() ?? '';
    }

    _nivelConsciencia = data.nivelConsciencia;
    _estadoNutricionalController.text = data.estadoNutricional ?? '';
    _peleMucosasController.text = data.peleMucosas ?? '';
    _sistemaRespiratorioController.text = data.sistemaRespiratorio ?? '';
    _sistemaCardiovascularController.text = data.sistemaCardiovascular ?? '';
    _abdomeController.text = data.abdome ?? '';
    _eliminacoesController.text = data.eliminacoesFisiologicas ?? '';
    _drenosSondasCateteresController.text = data.presencaDrenosSondasCateteres ?? '';
    _apoioFamiliarController.text = data.apoioFamiliarSocial ?? '';
    _necessidadesEmocionaisController.text = data.necessidadesEmocionaisEspirituais ?? '';
  }

  Future<void> _submitForm() async {
     if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Por favor, preencha todos os campos obrigatórios.');
      return;
    }

    setState(() => _isLoading = true);

    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final responsavelId = authService.currentUser?.id;

    if (responsavelId == null) {
      _showErrorSnackBar('Erro: Não foi possível identificar o usuário responsável.');
      setState(() => _isLoading = false);
      return;
    }

    // Debug: verificar valores dos checkboxes antes de salvar
    
    final antecedentesPessoais = AntecedentesPessoais(
      hasHAS: _hasHAS,
      hasDM: _hasDM,
      hasCardiopatias: _hasCardiopatias,
      hasAsmaDPOC: _hasAsmaDPOC,
      outrasDoencasCronicas: _outrasDoencasController.text,
      cirurgiasAnteriores: _cirurgiasAnterioresController.text,
      alergias: _alergiasController.text,
      medicamentosUsoContinuo: _medicamentosUsoContinuoController.text,
      temTabagismo: _temTabagismo,
      temEtilismo: _temEtilismo,
      temSedentarismo: _temSedentarismo,
      outrosHabitos: _outrosHabitosController.text,
    );
    

    final data = Anamnese(
      id: widget.anamnese?.id,
      pacienteId: widget.pacienteId,
      responsavelId: responsavelId,
      nomePaciente: widget.pacienteNome,
      dataAvaliacao: DateTime.now(),
      // Dados pessoais mantidos pois são obrigatórios - preenchidos do modelo Paciente
      idade: int.tryParse(_idadeController.text),
      sexo: _sexo,
      estadoCivil: _estadoCivilController.text.isNotEmpty ? _estadoCivilController.text : null,
      profissao: _profissaoController.text.isNotEmpty ? _profissaoController.text : null,
      queixaPrincipal: _queixaPrincipalController.text,
      historicoDoencaAtual: _historiaDoencaAtualController.text,
      historiaFamiliar: _historiaFamiliarController.text,
      nivelConsciencia: _nivelConsciencia,
      estadoNutricional: _estadoNutricionalController.text,
      peleMucosas: _peleMucosasController.text,
      sistemaRespiratorio: _sistemaRespiratorioController.text,
      sistemaCardiovascular: _sistemaCardiovascularController.text,
      abdome: _abdomeController.text,
      eliminacoesFisiologicas: _eliminacoesController.text,
      presencaDrenosSondasCateteres: _drenosSondasCateteresController.text,
      apoioFamiliarSocial: _apoioFamiliarController.text,
      necessidadesEmocionaisEspirituais: _necessidadesEmocionaisController.text,
      antecedentesPessoais: antecedentesPessoais,
      sinaisVitais: SinaisVitais(
        pressaoArterial: _pressaoArterialController.text,
        frequenciaCardiaca: int.tryParse(_fcController.text),
        frequenciaRespiratoria: int.tryParse(_frController.text),
        temperatura: double.tryParse(_tempController.text),
        saturacaoO2: int.tryParse(_spo2Controller.text),
      ),
    ).toJson();
    

    try {
      if (widget.isEditing) {
        await apiService.updateAnamnese(widget.anamnese!.id!, data);
      } else {
        await apiService.createAnamnese(widget.pacienteId, data);
      }

      if (mounted) {
        _showSuccessSnackBar('Ficha de avaliação salva com sucesso!');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao salvar ficha: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorRed),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.successGreen),
    );
  }

  String? _validateNonEmpty(String? value, String fieldName) {
    if (widget.isReadOnly) return null;
    if (value == null || value.trim().isEmpty) {
      return 'O campo $fieldName é obrigatório.';
    }
    return null;
  }
  
  @override
  Widget build(BuildContext context) {
    final String title = widget.isReadOnly 
        ? 'Visualizar Avaliação' 
        : (widget.isEditing ? 'Editar Avaliação' : 'Nova Avaliação');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Text(widget.pacienteNome, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [],
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
            _buildSectionCard(
              title: '1. Identificação do Paciente (Obrigatório)',
              icon: Icons.person_rounded,
              children: [
                 TextFormField(
                  initialValue: widget.pacienteNome,
                  enabled: false,
                  decoration: const InputDecoration(labelText: 'Nome Completo'),
                ),
                 TextFormField(
                  controller: _idadeController, 
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Idade (preenchida automaticamente)', 
                    helperText: 'Edite na aba "Dados" do paciente',
                  ), 
                  keyboardType: TextInputType.number,
                ),
                 DropdownButtonFormField<String>(
                  initialValue: _sexo,
                  decoration: const InputDecoration(
                    labelText: 'Sexo (preenchido automaticamente)',
                    helperText: 'Edite na aba "Dados" do paciente',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                    DropdownMenuItem(value: 'Feminino', child: Text('Feminino')),
                    DropdownMenuItem(value: 'Outro', child: Text('Outro')),
                  ],
                  onChanged: null,
                ),
                 TextFormField(
                  controller: _estadoCivilController,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Estado Civil (preenchido automaticamente)',
                    helperText: 'Edite na aba "Dados" do paciente',
                  ),
                ),
                 TextFormField(
                  controller: _profissaoController, 
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Profissão (preenchida automaticamente)',
                    helperText: 'Edite na aba "Dados" do paciente',
                  ),
                ),
              ],
            ),
             _buildSectionCard(
              title: '3. Histórico de Enfermagem (Opcional)',
              icon: Icons.history_edu_rounded,
              children: [
                TextFormField(controller: _queixaPrincipalController, readOnly: widget.isReadOnly, decoration: const InputDecoration(labelText: 'Queixa Principal'), maxLines: 3),
                TextFormField(controller: _historiaDoencaAtualController, readOnly: widget.isReadOnly, decoration: const InputDecoration(labelText: 'História da Doença Atual'), maxLines: 5),
                TextFormField(controller: _alergiasController, readOnly: widget.isReadOnly, decoration: const InputDecoration(labelText: 'Alergias'), maxLines: 2),
                TextFormField(controller: _medicamentosUsoContinuoController, readOnly: widget.isReadOnly, decoration: const InputDecoration(labelText: 'Uso Contínuo de Medicamentos'), maxLines: 3),
                TextFormField(controller: _cirurgiasAnterioresController, readOnly: widget.isReadOnly, decoration: const InputDecoration(labelText: 'Cirurgias Anteriores'), maxLines: 2),
                const SizedBox(height: 8),
                const Text("Doenças Crônicas", style: TextStyle(fontWeight: FontWeight.bold)),
                CheckboxListTile(value: _hasHAS, onChanged: widget.isReadOnly ? null : (val) => setState(() => _hasHAS = val!), title: const Text('HAS')),
                CheckboxListTile(value: _hasDM, onChanged: widget.isReadOnly ? null : (val) => setState(() => _hasDM = val!), title: const Text('DM')),
                CheckboxListTile(value: _hasCardiopatias, onChanged: widget.isReadOnly ? null : (val) => setState(() => _hasCardiopatias = val!), title: const Text('Cardiopatias')),
                CheckboxListTile(value: _hasAsmaDPOC, onChanged: widget.isReadOnly ? null : (val) => setState(() => _hasAsmaDPOC = val!), title: const Text('Asma/DPOC')),
                TextFormField(controller: _outrasDoencasController, readOnly: widget.isReadOnly, decoration: const InputDecoration(labelText: 'Outras')),
                const SizedBox(height: 8),
                const Text("Hábitos", style: TextStyle(fontWeight: FontWeight.bold)),
                CheckboxListTile(value: _temTabagismo, onChanged: widget.isReadOnly ? null : (val) => setState(() => _temTabagismo = val!), title: const Text('Tabagismo')),
                CheckboxListTile(value: _temEtilismo, onChanged: widget.isReadOnly ? null : (val) => setState(() => _temEtilismo = val!), title: const Text('Etilismo')),
                CheckboxListTile(value: _temSedentarismo, onChanged: widget.isReadOnly ? null : (val) => setState(() => _temSedentarismo = val!), title: const Text('Sedentarismo')),
                TextFormField(controller: _outrosHabitosController, readOnly: widget.isReadOnly, decoration: const InputDecoration(labelText: 'Outros')),
              ],
            ),
             _buildSectionCard(
              title: '4. Avaliação do Estado Atual (Obrigatório)',
              icon: Icons.monitor_heart_rounded,
              children: [
                TextFormField(
                  controller: _pressaoArterialController,
                  enabled: !widget.isReadOnly,
                  decoration: const InputDecoration(labelText: 'PA (mmHg) *'),
                  validator: (value) => _validateNonEmpty(value, 'PA'),
                ),
                TextFormField(
                  controller: _fcController, 
                  enabled: !widget.isReadOnly,
                  decoration: const InputDecoration(labelText: 'FC (bpm) *'), 
                  keyboardType: TextInputType.number,
                  validator: (value) => _validateNonEmpty(value, 'FC'),
                ),
                TextFormField(
                  controller: _frController, 
                  enabled: !widget.isReadOnly,
                  decoration: const InputDecoration(labelText: 'FR (irpm) *'), 
                  keyboardType: TextInputType.number,
                  validator: (value) => _validateNonEmpty(value, 'FR'),
                ),
                TextFormField(
                  controller: _tempController, 
                  enabled: !widget.isReadOnly,
                  decoration: const InputDecoration(labelText: 'Temp (°C) *'), 
                  keyboardType: TextInputType.number,
                  validator: (value) => _validateNonEmpty(value, 'Temp'),
                ),
                TextFormField(
                  controller: _spo2Controller, 
                  enabled: !widget.isReadOnly,
                  decoration: const InputDecoration(labelText: 'SpO2 (%) *'), 
                  keyboardType: TextInputType.number,
                  validator: (value) => _validateNonEmpty(value, 'SpO2'),
                ),
                 DropdownButtonFormField<String>(
                  initialValue: _nivelConsciencia,
                  decoration: const InputDecoration(labelText: 'Nível de Consciência *'),
                  items: const [
                    DropdownMenuItem(value: 'Lúcido', child: Text('Lúcido')),
                    DropdownMenuItem(value: 'Sonolento', child: Text('Sonolento')),
                    DropdownMenuItem(value: 'Confuso', child: Text('Confuso')),
                    DropdownMenuItem(value: 'Outros', child: Text('Outros')),
                  ],
                  onChanged: widget.isReadOnly ? null : (val) => setState(() => _nivelConsciencia = val),
                  validator: (value) => value == null ? 'Selecione o nível de consciência.' : null,
                ),
                 TextFormField(
                  controller: _peleMucosasController, 
                  enabled: !widget.isReadOnly,
                  decoration: const InputDecoration(labelText: 'Pele e Mucosas *'),
                  validator: (value) => _validateNonEmpty(value, 'Pele e Mucosas'),
                ),
                 TextFormField(
                  controller: _sistemaRespiratorioController, 
                  enabled: !widget.isReadOnly,
                  decoration: const InputDecoration(labelText: 'Sistema Respiratório *'),
                  validator: (value) => _validateNonEmpty(value, 'Sistema Respiratório'),
                ),
                 TextFormField(
                  controller: _sistemaCardiovascularController, 
                  enabled: !widget.isReadOnly,
                  decoration: const InputDecoration(labelText: 'Sistema Cardiovascular *'),
                  validator: (value) => _validateNonEmpty(value, 'Sistema Cardiovascular'),
                ),
                 TextFormField(
                  controller: _abdomeController, 
                  enabled: !widget.isReadOnly,
                  decoration: const InputDecoration(labelText: 'Abdome *'),
                  validator: (value) => _validateNonEmpty(value, 'Abdome'),
                ),
                 TextFormField(
                  controller: _eliminacoesController, 
                  enabled: !widget.isReadOnly,
                  decoration: const InputDecoration(labelText: 'Eliminações Fisiológicas *'),
                  validator: (value) => _validateNonEmpty(value, 'Eliminações'),
                ),
                 TextFormField(
                  controller: _drenosSondasCateteresController, 
                  enabled: !widget.isReadOnly,
                  decoration: const InputDecoration(labelText: 'Drenos/Sondas/Cateteres *'),
                  validator: (value) => _validateNonEmpty(value, 'Drenos/Sondas/Cateteres'),
                ),
              ],
            ),
             _buildSectionCard(
              title: '5. Aspectos Psicossociais (Opcional)',
              icon: Icons.psychology_rounded,
              children: [
                TextFormField(controller: _apoioFamiliarController, readOnly: widget.isReadOnly, decoration: const InputDecoration(labelText: 'Apoio Familiar/Social')),
                TextFormField(controller: _necessidadesEmocionaisController, readOnly: widget.isReadOnly, decoration: const InputDecoration(labelText: 'Necessidades Emocionais/Espirituais')),
              ],
            ),
          ],
        ),
      ),
    ),
    if (!widget.isReadOnly) _buildActionButtons(),
  ],
),
);
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
              label: const Text('Cancelar', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitForm,
              icon: _isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check, color: Colors.white),
              label: Text(
                _isLoading ? 'Salvando...' : 'Confirmar',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children.map((child) => Padding(padding: const EdgeInsets.only(bottom: 16), child: child)),
        ],
      ),
    );
  }
}