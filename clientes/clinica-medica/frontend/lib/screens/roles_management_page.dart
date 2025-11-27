import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/role.dart';
import '../providers/permissions_provider.dart';
import '../widgets/permission_guard.dart';
import 'role_editor_page.dart';

class RolesManagementPage extends StatefulWidget {
  final String negocioId;

  const RolesManagementPage({
    Key? key,
    required this.negocioId,
  }) : super(key: key);

  @override
  State<RolesManagementPage> createState() => _RolesManagementPageState();
}

class _RolesManagementPageState extends State<RolesManagementPage> {
  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    final provider = Provider.of<PermissionsProvider>(context, listen: false);
    await provider.carregarRoles(widget.negocioId);
  }

  Future<void> _deleteRole(Role role) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
          'Tem certeza que deseja excluir o perfil "${role.nomeCustomizado}"?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final provider = Provider.of<PermissionsProvider>(context, listen: false);
        await provider.excluirRole(widget.negocioId, role.id!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perfil excluído com sucesso'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _editRole(Role role) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoleEditorPage(
          negocioId: widget.negocioId,
          role: role,
        ),
      ),
    ).then((_) => _loadRoles());
  }

  void _createRole() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoleEditorPage(
          negocioId: widget.negocioId,
        ),
      ),
    ).then((_) => _loadRoles());
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null) return Colors.blue;
    try {
      return Color(int.parse(colorHex.replaceAll('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  IconData _parseIcon(String? iconName) {
    // Mapeamento simples de ícones
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Perfis'),
        elevation: 0,
      ),
      body: Consumer<PermissionsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erro: ${provider.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadRoles,
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            );
          }

          final roles = provider.negocioRoles;

          return RefreshIndicator(
            onRefresh: _loadRoles,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header com informações
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.admin_panel_settings, size: 32, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Perfis da Empresa',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Gerencie os perfis de acesso da sua equipe',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            _InfoChip(
                              icon: Icons.people,
                              label: '${roles.length} Perfis',
                            ),
                            const SizedBox(width: 8),
                            _InfoChip(
                              icon: Icons.security,
                              label: '${roles.where((r) => r.isSystem).length} Sistema',
                            ),
                            const SizedBox(width: 8),
                            _InfoChip(
                              icon: Icons.edit,
                              label: '${roles.where((r) => !r.isSystem).length} Customizados',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Lista de roles
                if (roles.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.work_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhum perfil customizado criado',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Crie perfis personalizados para sua equipe',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...roles.map((role) => _RoleCard(
                        role: role,
                        onEdit: () => _editRole(role),
                        onDelete: () => _deleteRole(role),
                        parseColor: _parseColor,
                        parseIcon: _parseIcon,
                      )),
              ],
            ),
          );
        },
      ),
      floatingActionButton: PermissionGuard(
        permission: 'settings.manage_permissions',
        child: FloatingActionButton.extended(
          onPressed: _createRole,
          icon: const Icon(Icons.add),
          label: const Text('Novo Perfil'),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _RoleCard extends StatelessWidget {
  final Role role;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Color Function(String?) parseColor;
  final IconData Function(String?) parseIcon;

  const _RoleCard({
    required this.role,
    required this.onEdit,
    required this.onDelete,
    required this.parseColor,
    required this.parseIcon,
  });

  String _getNivelHierarquicoText(int nivel) {
    switch (nivel) {
      case 1:
        return 'Administrativo';
      case 2:
        return 'Profissional';
      case 3:
        return 'Operacional';
      default:
        return 'Nível $nivel';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = parseColor(role.cor);
    final icon = parseIcon(role.icone);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Ícone com cor
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),

                  // Nome e tipo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                role.nomeCustomizado,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (role.isSystem)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'SISTEMA',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Ações
                  PermissionGuard(
                    permission: 'settings.manage_permissions',
                    child: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete' && !role.isSystem) {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 12),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        if (!role.isSystem)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 12),
                                Text('Excluir', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // Descrição
              if (role.descricaoCustomizada != null && role.descricaoCustomizada!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  role.descricaoCustomizada!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Informações adicionais
              Row(
                children: [
                  Icon(Icons.security, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${role.permissions.length} permissões',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    role.isActive ? Icons.check_circle : Icons.cancel,
                    size: 16,
                    color: role.isActive ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    role.isActive ? 'Ativo' : 'Inativo',
                    style: TextStyle(
                      fontSize: 12,
                      color: role.isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
