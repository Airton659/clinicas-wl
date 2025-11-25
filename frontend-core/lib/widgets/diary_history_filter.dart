// lib/widgets/diary_history_filter.dart - VERSÃO CORRIGIDA

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:analicegrubert/models/registro_diario.dart';

class DiaryHistoryFilter extends StatefulWidget {
  final Function(String? date, String? tipo) onFilterChanged;
  final String? initialDate;
  final String? initialTipo;

  const DiaryHistoryFilter({
    super.key,
    required this.onFilterChanged,
    this.initialDate,
    this.initialTipo,
  });

  @override
  State<DiaryHistoryFilter> createState() => _DiaryHistoryFilterState();
}

class _DiaryHistoryFilterState extends State<DiaryHistoryFilter> {
  DateTime? _selectedDate;
  String? _selectedTipo;
  final _dateController = TextEditingController();

  final List<Map<String, String>> _tiposRegistro = [
    {'value': '', 'label': 'Todos os tipos', 'icon': 'all_inclusive'},
    {'value': 'sinais_vitais', 'label': 'Sinais Vitais', 'icon': 'favorite'},
    {'value': 'medicacao', 'label': 'Medicações', 'icon': 'medication'},
    {'value': 'intercorrencia', 'label': 'Intercorrências', 'icon': 'warning'},
    {'value': 'atividade', 'label': 'Atividades', 'icon': 'directions_run'},
    {'value': 'anotacao', 'label': 'Anotações', 'icon': 'note_add'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _selectedDate = DateTime.parse(widget.initialDate!);
      _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
    }
    _selectedTipo = widget.initialTipo ?? '';
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  'Filtros do Histórico',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Filtro por Data
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Data específica',
                      suffixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                      hintText: 'Selecione uma data',
                    ),
                    readOnly: true,
                    onTap: _selectDate,
                  ),
                ),
                const SizedBox(width: 8),
                if (_selectedDate != null)
                  IconButton(
                    onPressed: _clearDate,
                    icon: const Icon(Icons.clear),
                    tooltip: 'Limpar filtro de data',
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Filtro por Tipo
            DropdownButtonFormField<String>(
              value: _selectedTipo,
              decoration: const InputDecoration(
                labelText: 'Tipo de Registro',
                border: OutlineInputBorder(),
              ),
              items: _tiposRegistro.map((tipo) {
                return DropdownMenuItem<String>(
                  value: tipo['value'],
                  child: Row(
                    children: [
                      _buildIcon(tipo['icon']!),
                      const SizedBox(width: 8),
                      Text(tipo['label']!),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTipo = value;
                });
                _applyFilters();
              },
            ),

            const SizedBox(height: 16),

            // Botões de ação rápida
            Wrap(
              spacing: 8,
              children: [
                _buildQuickFilterChip('Hoje', () => _setQuickDate(DateTime.now())),
                _buildQuickFilterChip('Ontem', () => _setQuickDate(DateTime.now().subtract(const Duration(days: 1)))),
                
                // *** CORREÇÃO APLICADA AQUI ***
                // Este botão agora limpa a data, para buscar os registros dos últimos dias
                // sem tentar carregar um checklist de um dia específico.
                _buildQuickFilterChip('Últimos 7 dias', () {
                    setState(() {
                      _selectedDate = null;
                      _dateController.clear();
                    });
                    // A lógica de buscar os "últimos 7 dias" será do backend,
                    // aqui apenas limpamos o filtro de data.
                    widget.onFilterChanged(null, _selectedTipo);
                }),
                
                _buildQuickFilterChip('Limpar filtros', _clearAllFilters),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(String iconName) {
    switch (iconName) {
      case 'favorite':
        return Icon(Icons.favorite, color: Colors.red.shade400, size: 20);
      case 'medication':
        return Icon(Icons.medication, color: Colors.blue.shade400, size: 20);
      case 'warning':
        return Icon(Icons.warning, color: Colors.orange.shade400, size: 20);
      case 'directions_run':
        return Icon(Icons.directions_run, color: Colors.green.shade400, size: 20);
      case 'note_add':
        return Icon(Icons.note_add, color: Colors.grey.shade600, size: 20);
      case 'all_inclusive':
      default:
        return Icon(Icons.all_inclusive, color: Colors.purple.shade400, size: 20);
    }
  }

  Widget _buildQuickFilterChip(String label, VoidCallback onPressed) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: onPressed,
      backgroundColor: Colors.blue.shade50,
      side: BorderSide(color: Colors.blue.shade200),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
      _applyFilters();
    }
  }

  void _clearDate() {
    setState(() {
      _selectedDate = null;
      _dateController.clear();
    });
    _applyFilters();
  }

  void _setQuickDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _dateController.text = DateFormat('dd/MM/yyyy').format(date);
    });
    _applyFilters();
  }

  void _clearAllFilters() {
    setState(() {
      _selectedDate = null;
      _selectedTipo = '';
      _dateController.clear();
    });
    _applyFilters();
  }

  void _applyFilters() {
    final dateString = _selectedDate != null 
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : null;
    
    final tipoString = (_selectedTipo?.isEmpty ?? true) ? null : _selectedTipo;
    
    widget.onFilterChanged(dateString, tipoString);
  }
}