// lib/screens/supervision_page.dart

import 'package:analicegrubert/api/api_service.dart';
import 'package:analicegrubert/models/diario.dart';
import 'package:analicegrubert/models/usuario.dart';
import 'package:analicegrubert/services/auth_service.dart';
import 'package:analicegrubert/utils/display_utils.dart';
import '../widgets/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class SupervisionPage extends StatefulWidget {
  final String pacienteId;
  final String pacienteNome;

  const SupervisionPage({
    super.key,
    required this.pacienteId,
    required this.pacienteNome,
  });

  @override
  State<SupervisionPage> createState() => _SupervisionPageState();
}

class _SupervisionPageState extends State<SupervisionPage> {
  late Future<List<Usuario>> _tecnicosFuture;
  late Future<List<Diario>> _diarioFuture;
  
  String? _selectedTecnicoId;
  Usuario? _selectedTecnico;
  List<Diario> _allDiarios = [];
  List<Diario> _filteredDiarios = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    setState(() {
      _tecnicosFuture = apiService.getTecnicosSupervisionados(widget.pacienteId);
      _diarioFuture = apiService.getDiario(widget.pacienteId).then((diarios) {
        _allDiarios = diarios;
        _filteredDiarios = diarios;
        return diarios;
      });
    });
  }

  void _filterDiariosByTecnico(String? tecnicoId) {
    setState(() {
      _selectedTecnicoId = tecnicoId;
      if (tecnicoId == null) {
        _selectedTecnico = null;
        _filteredDiarios = _allDiarios;
      } else {
        _filteredDiarios = _allDiarios.where((diario) => diario.tecnico.id == tecnicoId).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Supervisão de Técnicos', style: TextStyle(fontSize: 16)),
            Text(
              'Paciente: ${widget.pacienteNome}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildTecnicosSection(),
          const Divider(),
          Expanded(child: _buildDiarioSection()),
        ],
      ),
    );
  }

  Widget _buildTecnicosSection() {
    return FutureBuilder<List<Usuario>>(
      future: _tecnicosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: Text('Erro ao carregar técnicos: ${snapshot.error}')),
          );
        }

        final tecnicos = snapshot.data ?? [];

        if (tecnicos.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: Text('Nenhum técnico supervisionado encontrado para este paciente.')),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Técnicos Supervisionados',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8.0,
                children: [
                  FilterChip(
                    label: const Text('Todos'),
                    selected: _selectedTecnicoId == null,
                    onSelected: (selected) {
                      if (selected) _filterDiariosByTecnico(null);
                    },
                  ),
                  ...tecnicos.map((tecnico) => FilterChip(
                    label: Text(DisplayUtils.getTecnicoDisplayName(tecnico)),
                    selected: _selectedTecnicoId == tecnico.id,
                    onSelected: (selected) {
                      if (selected) {
                        _selectedTecnico = tecnico;
                        _filterDiariosByTecnico(tecnico.id);
                      } else {
                        _filterDiariosByTecnico(null);
                      }
                    },
                  )).toList(),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiarioSection() {
    return FutureBuilder<List<Diario>>(
      future: _diarioFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erro ao carregar diário: ${snapshot.error}'));
        }

        if (_filteredDiarios.isEmpty) {
          final message = _selectedTecnico != null
              ? 'Nenhuma anotação encontrada para ${_selectedTecnico!.email?.split('@').first ?? 'este técnico'}.'
              : 'Nenhuma anotação encontrada no diário.';
          
          return Center(child: Text(message));
        }

        return RefreshIndicator(
          onRefresh: () async => _loadData(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: _filteredDiarios.length,
            itemBuilder: (context, index) {
              final diario = _filteredDiarios[index];
              return _buildDiarioCard(diario);
            },
          ),
        );
      },
    );
  }

  Widget _buildDiarioCard(Diario diario) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatar(
                  imageUrl: null, // Tecnico não tem foto
                  userName: diario.tecnico.nome,
                  radius: 16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DisplayUtils.getTecnicoDisplayNameFromTecnico(diario.tecnico),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(diario.dataOcorrencia),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (diario.anotacaoGeral != null && diario.anotacaoGeral!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Anotação Geral:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Text(diario.anotacaoGeral!),
            ],
            if (diario.medicamentos != null) ...[
              const SizedBox(height: 12),
              const Text('Medicamentos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Text('${diario.medicamentos}', style: const TextStyle(color: Colors.blue)),
            ],
            if (diario.atividades != null) ...[
              const SizedBox(height: 12),
              const Text('Atividades:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Text('${diario.atividades}', style: const TextStyle(color: Colors.green)),
            ],
            if (diario.intercorrencias != null) ...[
              const SizedBox(height: 12),
              const Text('Intercorrências:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Text('${diario.intercorrencias}', style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}