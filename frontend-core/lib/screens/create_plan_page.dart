// lib/screens/create_plan_page.dart (VERSÃO COMPLETA E CORRIGIDA)

import 'package:analicegrubert/api/api_service.dart';
import 'package:analicegrubert/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CreatePlanPage extends StatefulWidget {
  final String pacienteId;

  const CreatePlanPage({super.key, required this.pacienteId});

  @override
  State<CreatePlanPage> createState() => _CreatePlanPageState();
}

class _CreatePlanPageState extends State<CreatePlanPage> {
  // Listas separadas para cada entidade, cobrindo a FichaCompleta
  final List<Map<String, dynamic>> _medicacoes = [];
  final List<Map<String, dynamic>> _orientacoes = [];
  final List<Map<String, dynamic>> _checklistItems = [];

  bool _isPublishing = false;

  // --- MÉTODOS DE GERENCIAMENTO (Adicionar/Editar/Remover) ---

  // Gerencia Medicações
  Future<void> _showAddOrEditMedicacaoDialog({int? index}) async {
    final isEditing = index != null;
    final nomeController = TextEditingController(
        text: isEditing ? _medicacoes[index!]['nome_medicamento'] : '');
    final dosagemController =
        TextEditingController(text: isEditing ? _medicacoes[index!]['dosagem'] : '');
    final instrucoesController = TextEditingController(
        text: isEditing ? _medicacoes[index!]['instrucoes'] : '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar Medicação' : 'Adicionar Medicação'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeController, decoration: const InputDecoration(labelText: 'Nome do Medicamento *')),
            TextField(controller: dosagemController, decoration: const InputDecoration(labelText: 'Dosagem *')),
            TextField(controller: instrucoesController, decoration: const InputDecoration(labelText: 'Instruções *')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (nomeController.text.isNotEmpty && dosagemController.text.isNotEmpty && instrucoesController.text.isNotEmpty) {
                Navigator.of(context).pop({
                  'nome_medicamento': nomeController.text,
                  'dosagem': dosagemController.text,
                  'instrucoes': instrucoesController.text,
                });
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => isEditing ? _medicacoes[index!] = result : _medicacoes.add(result));
    }
  }

  // Gerencia Orientações (similar ao anterior)
  Future<void> _showAddOrEditOrientacaoDialog({int? index}) async {
    final isEditing = index != null;
    final tituloController = TextEditingController(text: isEditing ? _orientacoes[index!]['titulo'] : '');
    final conteudoController = TextEditingController(text: isEditing ? _orientacoes[index!]['conteudo'] : '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Editar Orientação' : 'Adicionar Orientação',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // Campo Título
              TextField(
                controller: tituloController, 
                decoration: InputDecoration(
                  labelText: 'Título *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),
              
              // Campo Conteúdo - expandido verticalmente
              Expanded(
                child: TextField(
                  controller: conteudoController, 
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    labelText: 'Conteúdo *',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Botões de ação
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (tituloController.text.trim().isNotEmpty && conteudoController.text.trim().isNotEmpty) {
                        Navigator.of(context).pop({
                          'titulo': tituloController.text.trim(),
                          'conteudo': conteudoController.text.trim(),
                        });
                      }
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() => isEditing ? _orientacoes[index!] = result : _orientacoes.add(result));
    }
  }


  // Gerencia Checklist (similar ao anterior)
  Future<void> _showAddOrEditChecklistItemDialog({int? index}) async {
     final isEditing = index != null;
     final descricaoController = TextEditingController(text: isEditing ? _checklistItems[index!]['descricao_item'] : '');

     final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar Tarefa' : 'Adicionar Tarefa'),
        content: TextField(controller: descricaoController, decoration: const InputDecoration(labelText: 'Descrição da Tarefa *'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (descricaoController.text.isNotEmpty) Navigator.of(context).pop(descricaoController.text);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result != null) {
      final newItem = {'descricao_item': result, 'concluido': false};
      setState(() => isEditing ? _checklistItems[index!] = newItem : _checklistItems.add(newItem));
    }
  }
  
  // --- LÓGICA DE PUBLICAÇÃO COM DIAGNÓSTICO ---

  // Em lib/screens/create_plan_page.dart

  Future<void> _publicarPlano() async {
    debugPrint('🔍 PUBLICAR PLANO - Iniciando processo');
    debugPrint('📝 Orientações: ${_orientacoes.length}');
    debugPrint('📝 Checklist: ${_checklistItems.length}');
    debugPrint('📝 Medicações: ${_medicacoes.length}');

    if (_medicacoes.isEmpty && _orientacoes.isEmpty && _checklistItems.isEmpty) {
      debugPrint('⚠️ Nenhum item para publicar!');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicione ao menos um item ao plano.')));
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Publicação'),
        content: const Text('Esta ação irá substituir o plano de cuidado anterior e não poderá ser desfeita. Deseja continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Publicar')),
        ],
      ),
    );

    if (confirmado != true) {
      return;
    }

    setState(() => _isPublishing = true);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    String? consultaId;

    try {
      final negocioId = await authService.getNegocioId();
      if (negocioId == null) throw Exception("ID do Negócio não encontrado.");

      final consultaData = {
        'negocio_id': negocioId, 'paciente_id': widget.pacienteId,
        'data_consulta': DateTime.now().toIso8601String(),
        'resumo': 'Plano de cuidado gerado pelo aplicativo.', 'medico_id': null,
      };
      final novaConsulta = await apiService.createConsulta(widget.pacienteId, consultaData);
      consultaId = novaConsulta.id;

      // ---- CRIAÇÃO DAS ORIENTAÇÕES ----
      if (_orientacoes.isNotEmpty) {
        for (final orientacao in _orientacoes) {
          final orientacaoData = {...orientacao, 'negocio_id': negocioId, 'paciente_id': widget.pacienteId};
          // Passa o ID da consulta como parâmetro de URL, não no corpo
          await apiService.createOrientacao(widget.pacienteId, consultaId, orientacaoData);
        }
      }

      // ---- CRIAÇÃO DOS ITENS DE CHECKLIST ----
      if (_checklistItems.isNotEmpty) {
        for (final checklistItem in _checklistItems) {
          final checklistItemData = {...checklistItem, 'negocio_id': negocioId, 'paciente_id': widget.pacienteId};
           // Passa o ID da consulta como parâmetro de URL, não no corpo
          await apiService.createChecklistItem(widget.pacienteId, consultaId, checklistItemData);
        }
      }

      // ---- CRIAÇÃO DAS MEDICAÇÕES ----
      if (_medicacoes.isNotEmpty) {
        for (final medicacao in _medicacoes) {
          final medicacaoData = {...medicacao, 'negocio_id': negocioId, 'paciente_id': widget.pacienteId};
           // Passa o ID da consulta como parâmetro de URL, não no corpo
          await apiService.createMedicacao(widget.pacienteId, consultaId, medicacaoData);
        }
      }
      

      // ---- SUCESSO TOTAL ----
      if (mounted) {
        // Retorna o ID da nova consulta para que a tela anterior possa recarregar os dados corretos
        Navigator.of(context).pop(consultaId);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao publicar: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Plano de Cuidado'),
        actions: [
          if (_isPublishing)
            const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator(color: Colors.white)))
          else
            InkWell(
              onTap: _publicarPlano,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Center(
                  child: Text(
                    'Publicar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: DefaultTabController(
        length: 3, // Orientações, Checklist, Medicações
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Orientações'),
                // Tab(text: 'Prontuário'), // CAMPO PRONTUÁRIO COMENTADO A PEDIDO DO CLIENTE
                Tab(text: 'Checklist'),
                Tab(text: 'Medicações'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSectionPanel(
                    items: _orientacoes,
                    emptyMessage: 'Nenhuma orientação adicionada.',
                    onAdd: () => _showAddOrEditOrientacaoDialog(),
                    itemBuilder: (item, index) => ListTile(
                      leading: const Icon(Icons.notes, color: Colors.blueAccent),
                      title: Text(item['titulo']),
                      subtitle: Text(item['conteudo']),
                      trailing: _buildEditDeleteButtons(
                        onEdit: () => _showAddOrEditOrientacaoDialog(index: index),
                        onDelete: () => setState(() => _orientacoes.removeAt(index)),
                      ),
                    ),
                  ),

                  _buildSectionPanel(
                    items: _checklistItems,
                    emptyMessage: 'Nenhuma tarefa adicionada.',
                    onAdd: () => _showAddOrEditChecklistItemDialog(),
                    itemBuilder: (item, index) => ListTile(
                      leading: const Icon(Icons.check_box_outline_blank),
                      title: Text(item['descricao_item']),
                      trailing: _buildEditDeleteButtons(
                        onEdit: () => _showAddOrEditChecklistItemDialog(index: index),
                        onDelete: () => setState(() => _checklistItems.removeAt(index)),
                      ),
                    ),
                  ),

                  _buildSectionPanel(
                    items: _medicacoes,
                    emptyMessage: 'Nenhuma medicação adicionada.',
                    onAdd: () => _showAddOrEditMedicacaoDialog(),
                    itemBuilder: (item, index) => ListTile(
                      leading: const Icon(Icons.medication_outlined, color: Colors.redAccent),
                      title: Text(item['nome_medicamento']),
                      subtitle: Text("Dosagem: ${item['dosagem']}"),
                      trailing: _buildEditDeleteButtons(
                        onEdit: () => _showAddOrEditMedicacaoDialog(index: index),
                        onDelete: () => setState(() => _medicacoes.removeAt(index)),
                      ),
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

  // --- WIDGETS AUXILIARES PARA REUTILIZAÇÃO ---

  Widget _buildEditDeleteButtons({required VoidCallback onEdit, required VoidCallback onDelete}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: onDelete),
      ],
    );
  }

  Widget _buildSectionPanel({
    required List<Map<String, dynamic>> items,
    required String emptyMessage,
    required VoidCallback onAdd,
    required Widget Function(Map<String, dynamic> item, int index) itemBuilder,
  }) {
    return Column(
      children: [
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(emptyMessage, style: const TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: items.length,
                  itemBuilder: (context, index) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: itemBuilder(items[index], index),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar Novo Item'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        ),
      ],
    );
  }
}