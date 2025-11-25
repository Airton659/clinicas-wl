// lib/screens/edit_address_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../api/api_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/modern_widgets.dart';

class EditAddressPage extends StatefulWidget {
  final String pacienteId;
  final Map<String, dynamic>? initialAddress;

  const EditAddressPage({
    super.key,
    required this.pacienteId,
    this.initialAddress,
  });

  @override
  State<EditAddressPage> createState() => _EditAddressPageState();
}

class _EditAddressPageState extends State<EditAddressPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers para endereço
  final _ruaController = TextEditingController();
  final _numeroController = TextEditingController();
  final _bairroController = TextEditingController(); // ADICIONADO
  final _cidadeController = TextEditingController();
  final _cepController = TextEditingController();
  String? _selectedEstado;

  bool _isLoading = false;
  bool _isFetchingCep = false;

  // Formatadores
  final _cepFormatter =
      MaskTextInputFormatter(mask: '#####-###', filter: {"#": RegExp(r'[0-9]')});

  final List<String> _estadosBrasileiros = [
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS',
    'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC',
    'SP', 'SE', 'TO'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _ruaController.text = widget.initialAddress!['rua'] ?? '';
      _numeroController.text = widget.initialAddress!['numero'] ?? '';
      _bairroController.text = widget.initialAddress!['bairro'] ?? ''; // ADICIONADO
      _cidadeController.text = widget.initialAddress!['cidade'] ?? '';
      _selectedEstado = widget.initialAddress!['estado'];
      
      final initialCep = widget.initialAddress!['cep'] ?? '';
      if (initialCep.isNotEmpty) {
        _cepController.text = _cepFormatter.maskText(initialCep);
      }
    }
    _cepController.addListener(_onCepChanged);
  }

  @override
  void dispose() {
    _cepController.removeListener(_onCepChanged);
    _ruaController.dispose();
    _numeroController.dispose();
    _bairroController.dispose(); // ADICIONADO
    _cidadeController.dispose();
    _cepController.dispose();
    super.dispose();
  }
  
  void _onCepChanged() {
    final unmaskedCep = _cepFormatter.getUnmaskedText();
    if (unmaskedCep.length == 8) {
      _fetchAddressFromCep(unmaskedCep);
    }
  }

  Future<void> _fetchAddressFromCep(String cep) async {
    setState(() => _isFetchingCep = true);
    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$cep/json/');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['erro'] != true) {
          setState(() {
            _ruaController.text = data['logradouro'] ?? '';
            _bairroController.text = data['bairro'] ?? ''; // ADICIONADO
            _cidadeController.text = data['localidade'] ?? '';
            _selectedEstado = data['uf'];
          });
        } else {
          _showErrorSnackBar('CEP não encontrado.');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Erro ao buscar CEP. Verifique sua conexão.');
    } finally {
      if (mounted) {
        setState(() => _isFetchingCep = false);
      }
    }
  }

  bool _validateAddressData() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedEstado == null) {
        _showErrorSnackBar('CEP inválido ou não preenchido');
        return false;
      }
      return true;
    }
    return false;
  }

  Future<void> _saveAddress() async {
    if (!_validateAddressData()) return;

    setState(() => _isLoading = true);

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final addressData = {
        'rua': _ruaController.text.trim(),
        'numero': _numeroController.text.trim(),
        'bairro': _bairroController.text.trim(), // ADICIONADO
        'cidade': _cidadeController.text.trim(),
        'estado': _selectedEstado,
        'cep': _cepFormatter.getUnmaskedText(),
      };

      await apiService.updatePatientAddress(widget.pacienteId, addressData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Endereço salvo com sucesso!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao salvar endereço: $e');
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
          'Endereço do Paciente',
          style: TextStyle(
            color: AppTheme.neutralGray800,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: _buildAddressForm(),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ModernCard(
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
                  child: const Icon(Icons.location_on_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Endereço',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.neutralGray800,
                      ),
                    ),
                    Text(
                      'Preencha o CEP para carregar',
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: ModernTextField(
                    label: 'CEP *',
                    hint: '12345-678',
                    prefixIcon: Icons.location_searching_outlined,
                    suffixIcon: _isFetchingCep ? null : Icons.search,
                    controller: _cepController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_cepFormatter],
                    validator: (v) =>
                        v!.length != 9 ? 'CEP inválido' : null,
                  ),
                ),
                if (_isFetchingCep)
                  const Padding(
                    padding: EdgeInsets.only(left: 8, top: 16),
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ModernTextField(
                    label: 'Nº *',
                    hint: '123',
                    controller: _numeroController,
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v!.isEmpty ? 'Obrigatório' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ModernTextField(
              label: 'Rua *',
              hint: 'Preenchido automaticamente',
              prefixIcon: Icons.home_outlined,
              controller: _ruaController,
              enabled: false,
              validator: (v) =>
                  v!.isEmpty ? 'Preencha o CEP' : null,
            ),
            const SizedBox(height: 16),
            ModernTextField( // ADICIONADO
              label: 'Bairro *',
              hint: 'Preenchido automaticamente',
              prefixIcon: Icons.location_city_outlined,
              controller: _bairroController,
              enabled: false,
              validator: (v) => v!.isEmpty ? 'Preencha o CEP' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ModernTextField(
                    label: 'Cidade *',
                    hint: 'Preenchido automaticamente',
                    prefixIcon: Icons.location_city_outlined,
                    controller: _cidadeController,
                    enabled: false,
                    validator: (v) =>
                        v!.isEmpty ? 'Preencha o CEP' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.neutralGray100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.neutralGray200),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedEstado,
                      hint: const Text('Estado *'),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.map_outlined),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      onChanged: null,
                      items: _estadosBrasileiros
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
          text: 'Salvar Endereço',
          onPressed: _saveAddress,
          isLoading: _isLoading,
          icon: Icons.save_rounded,
        ),
      ),
    );
  }
}