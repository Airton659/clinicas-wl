import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/role.dart';
import '../models/permission.dart';
import '../providers/permissions_provider.dart';

class RoleEditorPage extends StatefulWidget {
  final String negocioId;
  final Role? role; // null = criar novo, não-null = editar

  const RoleEditorPage({
    Key? key,
    required this.negocioId,
    this.role,
  }) : super(key: key);

  @override
  State<RoleEditorPage> createState() => _RoleEditorPageState();
}

class _RoleEditorPageState extends State<RoleEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _tipoController = TextEditingController(text: 'perfil_1'); // NOVO: Controller para tipo

  String _tipo = 'perfil_1';
  int _nivelHierarquico = 2;
  String _cor = '#2196F3';
  String _icone = 'person';
  Set<String> _selectedPermissions = {};
  bool _isActive = true;
  bool _loading = false;

  Map<String, List<Permission>> _permissionsByCategory = {};

  @override
  void initState() {
    super.initState();
    _loadPermissions();

    // Se está editando, preencher campos
    if (widget.role != null) {
      final role = widget.role!;
      _nomeController.text = role.nomeCustomizado;
      _descricaoController.text = role.descricaoCustomizada ?? '';
      _tipo = role.tipo;
      _tipoController.text = role.tipo; // Atualizar controller também
      _nivelHierarquico = role.nivelHierarquico;
      _cor = role.cor ?? '#2196F3';
      _icone = role.icone ?? 'person';
      _selectedPermissions = Set.from(role.permissions);
      _isActive = role.isActive;
    } else {
      // Se está criando novo, gerar tipo automaticamente
      _gerarProximoTipo();
    }
  }

  Future<void> _gerarProximoTipo() async {
    try {
      final provider = Provider.of<PermissionsProvider>(context, listen: false);

      // Forçar reload dos perfis
      debugPrint('🔄 Carregando perfis para gerar próximo tipo...');
      await provider.carregarRoles("rlAB6phw0EBsBFeDyOt6");

      debugPrint('📋 Total de perfis carregados: ${provider.negocioRoles.length}');
      for (var role in provider.negocioRoles) {
        debugPrint('   - ${role.tipo}: ${role.nomeCustomizado}');
      }

      // Pegar todos os tipos existentes (exceto admin)
      final tiposExistentes = provider.negocioRoles
          .where((r) => r.tipo != 'admin' && r.tipo.startsWith('perfil_'))
          .map((r) => r.tipo)
          .toList();

      debugPrint('🔍 Tipos existentes (perfil_*): $tiposExistentes');

      // Encontrar o próximo número disponível
      int proximoNumero = 1;
      while (tiposExistentes.contains('perfil_$proximoNumero')) {
        debugPrint('   perfil_$proximoNumero já existe, tentando próximo...');
        proximoNumero++;
      }

      debugPrint('✅ Próximo tipo gerado: perfil_$proximoNumero');

      if (mounted) {
        setState(() {
          _tipo = 'perfil_$proximoNumero';
          _tipoController.text = 'perfil_$proximoNumero'; // Atualizar controller também!
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao gerar próximo tipo: $e');
      // Se der erro, usar perfil_1 como fallback
      if (mounted) {
        setState(() {
          _tipo = 'perfil_1';
        });
      }
    }
  }

  Future<void> _loadPermissions() async {
    final provider = Provider.of<PermissionsProvider>(context, listen: false);
    await provider.carregarPermissoesPorCategoria();

    setState(() {
      _permissionsByCategory = provider.permissionsByCategory;
    });
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _tipoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);

    try {
      final provider = Provider.of<PermissionsProvider>(context, listen: false);

      if (widget.role == null) {
        // VALIDAÇÃO: Verificar se já existe perfil com esse tipo
        await provider.carregarRoles(widget.negocioId);
        final tipoJaExiste = provider.negocioRoles.any((r) => r.tipo == _tipo && r.id != widget.role?.id);

        if (tipoJaExiste) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Erro: Já existe um perfil com o tipo "$_tipo"! Isso causaria conflito no sistema.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          setState(() => _loading = false);
          return;
        }

        // Criar novo
        await provider.criarRole(
          widget.negocioId,
          tipo: _tipo,
          nivelHierarquico: _nivelHierarquico,
          nomeCustomizado: _nomeController.text,
          descricaoCustomizada: _descricaoController.text.isNotEmpty
              ? _descricaoController.text
              : null,
          cor: _cor,
          icone: _icone,
          permissions: _selectedPermissions.toList(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perfil criado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // Atualizar existente
        await provider.atualizarRole(
          widget.negocioId,
          widget.role!.id!,
          nomeCustomizado: _nomeController.text,
          descricaoCustomizada: _descricaoController.text.isNotEmpty
              ? _descricaoController.text
              : null,
          cor: _cor,
          icone: _icone,
          permissions: _selectedPermissions.toList(),
          isActive: _isActive,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perfil atualizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceAll('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.role != null;
    final isSystemRole = widget.role?.isSystem ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Perfil' : 'Novo Perfil'),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _save,
              child: Text(
                'SALVAR',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Informações Básicas
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informações Básicas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Nome
                          TextFormField(
                            controller: _nomeController,
                            decoration: const InputDecoration(
                              labelText: 'Nome do Perfil *',
                              hintText: 'Ex: Veterinário Senior',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.badge),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Nome é obrigatório';
                              }
                              if (value.length < 3) {
                                return 'Nome deve ter no mínimo 3 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Descrição
                          TextFormField(
                            controller: _descricaoController,
                            decoration: const InputDecoration(
                              labelText: 'Descrição (Opcional)',
                              hintText: 'Descreva as responsabilidades deste perfil',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.description),
                            ),
                            maxLines: 3,
                            maxLength: 200,
                          ),
                          const SizedBox(height: 16),

                          // Status (só edição)
                          if (isEditing && !isSystemRole)
                            SwitchListTile(
                              title: const Text('Perfil Ativo'),
                              subtitle: const Text(
                                'Usuários com perfil inativo não podem acessar o sistema',
                              ),
                              value: _isActive,
                              onChanged: (value) {
                                setState(() => _isActive = value);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Personalização
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Personalização Visual',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Cor
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Cor: '),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _parseColor(_cor),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _cor,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  '#2196F3', // Azul
                                  '#4CAF50', // Verde
                                  '#FF9800', // Laranja
                                  '#9C27B0', // Roxo
                                  '#F44336', // Vermelho
                                  '#00BCD4', // Ciano
                                  '#E91E63', // Rosa
                                  '#795548', // Marrom
                                  '#607D8B', // Cinza Azulado
                                  '#FFC107', // Âmbar
                                  '#009688', // Teal
                                  '#673AB7', // Roxo Profundo
                                ].map((color) {
                                  return InkWell(
                                    onTap: () => setState(() => _cor = color),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: _parseColor(color),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _cor == color
                                              ? Colors.black
                                              : Colors.grey[300]!,
                                          width: _cor == color ? 3 : 1,
                                        ),
                                        boxShadow: _cor == color
                                            ? [
                                                BoxShadow(
                                                  color: _parseColor(color)
                                                      .withOpacity(0.5),
                                                  blurRadius: 8,
                                                  spreadRadius: 2,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Ícone
                          Row(
                            children: [
                              const Text('Ícone: '),
                              const SizedBox(width: 8),
                              Icon(_getIcon(_icone), size: 32),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    'person',
                                    'medical_services',
                                    'admin_panel_settings',
                                    'work',
                                    'people',
                                    'local_hospital',
                                    'verified_user',
                                    'assignment',
                                  ].map((iconName) {
                                    final isSelected = _icone == iconName;
                                    return GestureDetector(
                                      onTap: () =>
                                          setState(() => _icone = iconName),
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .primaryColor
                                                  .withOpacity(0.1)
                                              : Colors.grey[200],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSelected
                                                ? Theme.of(context).primaryColor
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          _getIcon(iconName),
                                          color: isSelected
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Permissões
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Permissões',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_selectedPermissions.length} selecionadas',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Selecione as ações que este perfil pode realizar',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    // Pega todas as permissões disponíveis
                                    final allPermissionIds = _permissionsByCategory.values
                                        .expand((perms) => perms.map((p) => p.id))
                                        .toSet();

                                    // Se todas estão selecionadas, desmarca todas
                                    if (_selectedPermissions.length == allPermissionIds.length) {
                                      _selectedPermissions.clear();
                                    } else {
                                      // Senão, seleciona todas
                                      _selectedPermissions = Set.from(allPermissionIds);
                                    }
                                  });
                                },
                                icon: Icon(
                                  _selectedPermissions.length ==
                                          _permissionsByCategory.values
                                              .expand((perms) => perms.map((p) => p.id))
                                              .length
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  size: 20,
                                ),
                                label: Text(
                                  _selectedPermissions.length ==
                                          _permissionsByCategory.values
                                              .expand((perms) => perms.map((p) => p.id))
                                              .length
                                      ? 'Desmarcar Todas'
                                      : 'Selecionar Todas',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Lista de permissões por categoria
                          if (_permissionsByCategory.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else
                            ..._permissionsByCategory.entries.map((entry) {
                              final categoria = entry.key;
                              final permissions = entry.value;

                              return _PermissionCategorySection(
                                categoria: categoria,
                                permissions: permissions,
                                selectedPermissions: _selectedPermissions,
                                onPermissionToggle: (permissionId, selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedPermissions.add(permissionId);
                                    } else {
                                      _selectedPermissions.remove(permissionId);
                                    }
                                  });
                                },
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 80), // Espaço para o FAB
                ],
              ),
            ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Salvar Perfil'),
            ),
    );
  }

  IconData _getIcon(String iconName) {
    final iconMap = {
      'person': Icons.person,
      'medical_services': Icons.medical_services,
      'admin_panel_settings': Icons.admin_panel_settings,
      'work': Icons.work,
      'people': Icons.people,
      'local_hospital': Icons.local_hospital,
      'verified_user': Icons.verified_user,
      'assignment': Icons.assignment,
    };
    return iconMap[iconName] ?? Icons.person;
  }
}

class _PermissionCategorySection extends StatelessWidget {
  final String categoria;
  final List<Permission> permissions;
  final Set<String> selectedPermissions;
  final Function(String, bool) onPermissionToggle;

  const _PermissionCategorySection({
    required this.categoria,
    required this.permissions,
    required this.selectedPermissions,
    required this.onPermissionToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        categoria,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${permissions.where((p) => selectedPermissions.contains(p.id)).length}/${permissions.length} selecionadas',
        style: const TextStyle(fontSize: 12),
      ),
      children: permissions.map((permission) {
        final isSelected = selectedPermissions.contains(permission.id);
        return CheckboxListTile(
          title: Text(permission.nome),
          subtitle: Text(
            permission.descricao,
            style: const TextStyle(fontSize: 12),
          ),
          value: isSelected,
          onChanged: (value) {
            onPermissionToggle(permission.id, value ?? false);
          },
          dense: true,
        );
      }).toList(),
    );
  }
}
