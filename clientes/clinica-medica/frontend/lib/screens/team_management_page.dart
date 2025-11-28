// lib/screens/team_management_page.dart

import 'package:analicegrubert/api/api_service.dart';
import 'package:analicegrubert/models/usuario.dart';
import 'package:analicegrubert/models/role.dart';
import 'package:analicegrubert/utils/display_utils.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/permission_guard.dart';
import '../providers/permissions_provider.dart';
import '../services/auth_service.dart';
import 'roles_management_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TeamManagementPage extends StatefulWidget {
  final String? initialRoleFilter;
  final bool? showOnlyPatientsWithoutNurse;
  final bool? showOnlyPatientsWithoutTechnician;
  final bool? showOnlyPatientsWithoutDoctor;
  final bool? showOnlyTechniciansWithoutSupervisor;

  const TeamManagementPage({
    super.key,
    this.initialRoleFilter,
    this.showOnlyPatientsWithoutNurse,
    this.showOnlyPatientsWithoutTechnician,
    this.showOnlyPatientsWithoutDoctor,
    this.showOnlyTechniciansWithoutSupervisor,
  });

  @override
  State<TeamManagementPage> createState() => _TeamManagementPageState();
}

class _TeamManagementPageState extends State<TeamManagementPage> {
  late Future<List<Usuario>> _usersFuture;
  List<Usuario> _allUsers = [];
  List<Usuario> _filteredUsers = [];
  List<Role> _availableRoles = [];
  final TextEditingController _searchController = TextEditingController();
  String? _activeRoleFilter;
  String _statusFilter = 'ativo'; // O padrão continua sendo 'ativo'

  @override
  void initState() {
    super.initState();
    _activeRoleFilter = widget.initialRoleFilter;
    _fetchAndCacheUsers();
    _searchController.addListener(_filterUsers);
    _loadUserPermissions();
    _loadAvailableRoles();
  }

  /// Carrega permissões do usuário atual
  void _loadUserPermissions() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final permissionsProvider =
        Provider.of<PermissionsProvider>(context, listen: false);
    final currentUser = authService.currentUser;

    if (currentUser != null && currentUser.id != null) {
      const negocioId = "rlAB6phw0EBsBFeDyOt6"; // ID do negócio
      permissionsProvider.carregarPermissoesUsuario(negocioId, currentUser.id!);
      print(
          '🔐 Carregando permissões do usuário ${currentUser.email} no negócio $negocioId');
    }
  }

  /// Carrega roles disponíveis do sistema RBAC
  void _loadAvailableRoles() async {
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    final permissionsProvider =
        Provider.of<PermissionsProvider>(context, listen: false);

    try {
      await permissionsProvider.carregarRoles(negocioId);
      setState(() {
        // Filtrar roles: excluir apenas 'admin'
        // NÃO filtrar por isActive - usuários podem ter roles inativas
        _availableRoles = permissionsProvider.negocioRoles
            .where((role) => role.tipo != 'admin')
            .toList();
      });
      print(
          '📋 Roles carregados: ${_availableRoles.map((r) => r.tipo).toList()}');
    } catch (e) {
      print('❌ Erro ao carregar roles: $e');
    }
  }

  void _fetchAndCacheUsers({bool forceRefresh = false}) {
    print(
        '📡 TeamManagementPage: _fetchAndCacheUsers chamado (forceRefresh: $forceRefresh)');
    final apiService = Provider.of<ApiService>(context, listen: false);

    // Otimização: Só busca 'todos' se o filtro for 'Todos' ou 'Inativos'
    final apiStatusFilter = (_statusFilter == 'ativo') ? 'ativo' : 'all';

    setState(() {
      _usersFuture = apiService
          .getAllUsersInBusiness(
        status: apiStatusFilter,
        forceRefresh: forceRefresh,
      )
          .then((users) {
        print(
            '📥 TeamManagementPage: Recebidos ${users.length} usuários da API');
        _allUsers = users;
        _filterUsers();
        return users;
      });
    });
  }

  void _filterUsers() {
    // *** CORREÇÃO APLICADA AQUI ***
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    final query = _searchController.text.toLowerCase();

    print('🔍 TeamManagementPage: _filterUsers chamado');
    print('   Total usuários: ${_allUsers.length}');
    print(
        '   showOnlyPatientsWithoutTechnician: ${widget.showOnlyPatientsWithoutTechnician}');

    setState(() {
      _filteredUsers = _allUsers.where((user) {
        // Excluir super_admins da lista de equipe
        if (user.isSuperAdmin) return false;

        // Filtro por Papel
        final userRole = user.roles?[negocioId];
        final roleMatch =
            _activeRoleFilter == null || userRole == _activeRoleFilter;
        if (!roleMatch) return false;

        // Filtro por Status (local)
        final userStatus = user.status_por_negocio?[negocioId];
        if (_statusFilter == 'ativo' && userStatus == 'inativo') {
          return false;
        }
        if (_statusFilter == 'inativo' && userStatus != 'inativo') {
          return false;
        }

        // Filtro específico: "Pacientes sem Enfermeiro"
        if (widget.showOnlyPatientsWithoutNurse == true) {
          // Só mostra clientes/pacientes que não têm enfermeiro vinculado
          final isPatient = user.roles?[negocioId] == 'cliente';
          final hasNoNurse =
              user.enfermeiroId == null || user.enfermeiroId!.isEmpty;
          if (!isPatient || !hasNoNurse) {
            return false;
          }
        }

        // Filtro específico: "Pacientes sem Técnico"
        if (widget.showOnlyPatientsWithoutTechnician == true) {
          final isPatient = user.roles?[negocioId] == 'cliente';
          // CORREÇÃO: Verificar se o próprio paciente tem técnicos vinculados
          final pacienteTemTecnico =
              user.tecnicosIds != null && user.tecnicosIds!.isNotEmpty;

          print(
              '   🏥 Paciente ${user.nome}: isPatient=$isPatient, temTecnico=$pacienteTemTecnico');
          print('     paciente.tecnicosIds=${user.tecnicosIds}');

          if (!isPatient || pacienteTemTecnico) {
            return false;
          }
        }

        // Filtro específico: "Pacientes sem Médico"
        if (widget.showOnlyPatientsWithoutDoctor == true) {
          final isPatient = user.roles?[negocioId] == 'cliente';
          final hasNoDoctor = user.medicoId == null || user.medicoId!.isEmpty;
          if (!isPatient || !hasNoDoctor) {
            return false;
          }
        }

        // Filtro específico: "Técnicos sem Supervisor"
        if (widget.showOnlyTechniciansWithoutSupervisor == true) {
          // Só mostra técnicos que não têm supervisor vinculado
          final isTechnician = user.roles?[negocioId] == 'tecnico';
          final hasNoSupervisor =
              user.supervisor_id == null || user.supervisor_id!.isEmpty;
          if (!isTechnician || !hasNoSupervisor) {
            return false;
          }
        }

        // Filtro por Busca (texto)
        if (query.isNotEmpty) {
          final nameMatch = user.nome?.toLowerCase().contains(query) ?? false;
          final emailMatch = user.email?.toLowerCase().contains(query) ?? false;
          return nameMatch || emailMatch;
        }

        return true;
      }).toList();

      print(
          '📊 TeamManagementPage: Filtro final - ${_filteredUsers.length} usuários exibidos');
      for (final user in _filteredUsers) {
        print('   - ${user.nome} (${user.roles?["rlAB6phw0EBsBFeDyOt6"]})');
      }
    });
  }

  void _reloadData() {
    print('🔄 TeamManagementPage: _reloadData chamado');
    // Limpa cache agressivamente antes de recarregar
    final apiService = Provider.of<ApiService>(context, listen: false);
    apiService.clearCache('getAllUsersInBusiness');
    apiService.clearCache(); // Limpa todo o cache
    print('🗑️ TeamManagementPage: Cache limpo');

    _fetchAndCacheUsers(forceRefresh: true);
  }

  void _setRoleFilter(String? role) {
    setState(() {
      _activeRoleFilter = role;
      _filterUsers();
    });
  }

  void _setStatusFilter(String status) {
    setState(() {
      _statusFilter = status;
      _fetchAndCacheUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getDisplayRoleName(String role) {
    // Tentar encontrar o role na lista de roles carregados
    try {
      final roleObj = _availableRoles.firstWhere((r) => r.tipo == role);
      return roleObj.nomeCustomizado;
    } catch (e) {
      // Fallback para nomes padrão se não encontrar
      switch (role) {
        case 'cliente':
          return 'Paciente';
        case 'profissional':
          return 'Enfermeiro';
        case 'tecnico':
          return 'Técnico';
        case 'medico':
          return 'Médico';
        case 'admin':
          return 'Gestor';
        default:
          return role;
      }
    }
  }

  Future<void> _showChangeRoleDialog(Usuario user) async {
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    String? selectedRole = user.roles?[negocioId] ?? 'cliente';

    // Usar roles dinâmicos do sistema RBAC (excluindo admin)
    final rolesDisponiveis = _availableRoles.map((r) => r.tipo).toList();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Alterar Papel de ${user.email}'),
              content: DropdownButtonFormField<String>(
                value: selectedRole,
                items: rolesDisponiveis.map((String role) {
                  return DropdownMenuItem<String>(
                    value: role,
                    child: Text(_getDisplayRoleName(role)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setDialogState(() {
                    selectedRole = newValue!;
                  });
                },
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Salvar'),
                  onPressed: () async {
                    if (user.id == null) return;
                    final apiService =
                        Provider.of<ApiService>(context, listen: false);
                    try {
                      await apiService.updateUserRole(user.id!, selectedRole!);
                      if (mounted) {
                        Navigator.of(context).pop();
                        // Limpar filtro de role para mostrar todos os usuários
                        setState(() {
                          _activeRoleFilter = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Papel alterado com sucesso!')),
                        );
                        _reloadData();
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Erro ao alterar o papel: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showUpdateStatusDialog(Usuario user, String newStatus) async {
    final isActivating = newStatus == 'ativo';
    final title = isActivating ? 'Reativar Usuário' : 'Inativar Usuário';
    final content =
        'Tem certeza que deseja ${isActivating ? 'reativar' : 'inativar'} o usuário ${user.email}?';

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(isActivating ? 'Reativar' : 'Inativar')),
            ],
          ),
        ) ??
        false;

    if (confirmed && mounted) {
      if (user.id == null) return;
      final apiService = Provider.of<ApiService>(context, listen: false);
      try {
        await apiService.updateUserStatus(user.id!, newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Usuário ${isActivating ? 'reativado' : 'inativado'} com sucesso!')),
        );
        _reloadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // *** CORREÇÃO APLICADA AQUI ***
    const negocioId = "rlAB6phw0EBsBFeDyOt6";

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showOnlyPatientsWithoutNurse == true
            ? 'Pacientes sem Enfermeiro'
            : widget.showOnlyPatientsWithoutTechnician == true
                ? 'Pacientes sem Técnico'
                : widget.showOnlyPatientsWithoutDoctor == true
                    ? 'Pacientes sem Médico'
                    : widget.showOnlyTechniciansWithoutSupervisor == true
                        ? 'Técnicos sem Supervisor'
                        : 'Gestão de Equipe'),
        actions: [
          PermissionGuard(
            permission: 'settings.manage_permissions',
            child: IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const RolesManagementPage(negocioId: negocioId),
                  ),
                );
              },
              tooltip: 'Gerenciar Perfis e Permissões',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reloadData,
            tooltip: 'Recarregar Lista',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar por nome ou email',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filtrar por Papel:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Wrap(
                    spacing: 8.0,
                    children: [
                      FilterChip(
                        label: const Text('Todos'),
                        selected: _activeRoleFilter == null,
                        onSelected: (selected) => _setRoleFilter(null),
                      ),
                      // Gerar FilterChips dinamicamente baseado em roles carregados
                      ..._availableRoles.map((role) {
                        return FilterChip(
                          label: Text(role.nomeCustomizado),
                          selected: _activeRoleFilter == role.tipo,
                          onSelected: (selected) => _setRoleFilter(role.tipo),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Filtrar por Status:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  children: [
                    FilterChip(
                      label: const Text('Todos'),
                      selected: _statusFilter == 'all',
                      onSelected: (selected) => _setStatusFilter('all'),
                    ),
                    FilterChip(
                      label: const Text('Ativos'),
                      selected: _statusFilter == 'ativo',
                      onSelected: (selected) => _setStatusFilter('ativo'),
                    ),
                    FilterChip(
                      label: const Text('Inativos'),
                      selected: _statusFilter == 'inativo',
                      onSelected: (selected) => _setStatusFilter('inativo'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder<List<Usuario>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child:
                          Text('Erro ao carregar usuários: ${snapshot.error}'));
                }
                if (_filteredUsers.isEmpty) {
                  return const Center(
                      child: Text(
                          'Nenhum usuário encontrado para os filtros aplicados.'));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 1200
                        ? 4
                        : MediaQuery.of(context).size.width > 600
                            ? 3
                            : 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    final userRole = user.roles?[negocioId] ?? 'sem-papel';
                    final isInactive =
                        user.status_por_negocio?[negocioId] == 'inativo';
                    return _buildUserCard(user, userRole, isInactive);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  LinearGradient _getRoleGradient(String role) {
    // Tratamento especial para roles do sistema
    if (role == 'admin') {
      return const LinearGradient(
        colors: [Color(0xFFE57373), Color(0xFFD32F2F)], // Vermelho
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    if (role == 'cliente') {
      return const LinearGradient(
        colors: [Color(0xFF64B5F6), Color(0xFF1976D2)], // Azul
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    // Para roles customizadas, busca no cache
    final customRole = _availableRoles.firstWhere(
      (r) => r.tipo == role,
      orElse: () => Role(
        negocioId: 'rlAB6phw0EBsBFeDyOt6',
        tipo: role,
        nivelHierarquico: 50,
        nomeCustomizado: role,
        cor: '#9E9E9E',
        icone: 'person',
        permissions: [],
        isActive: true,
      ),
    );

    // Converte a cor hex para Color
    final colorHex = customRole.cor ?? '#9E9E9E';
    final colorValue = int.parse(colorHex.replaceFirst('#', '0xFF'));
    final baseColor = Color(colorValue);

    // Cria um gradiente com a cor base (mais clara) e uma versão mais escura
    final darkerColor = Color.fromARGB(
      255,
      (baseColor.red * 0.8).round(),
      (baseColor.green * 0.8).round(),
      (baseColor.blue * 0.8).round(),
    );

    return LinearGradient(
      colors: [baseColor, darkerColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  String _getUserInitials(Usuario user) {
    final displayName = DisplayUtils.getUserDisplayName(user);
    if (displayName.length >= 2) {
      return displayName.substring(0, 2).toUpperCase();
    }
    return displayName.substring(0, 1).toUpperCase();
  }

  IconData _getRoleIcon(String role) {
    // Tratamento especial para roles do sistema
    if (role == 'admin') {
      return Icons.admin_panel_settings;
    }

    if (role == 'cliente') {
      return Icons.person;
    }

    // Para roles customizadas, busca no cache
    final customRole = _availableRoles.firstWhere(
      (r) => r.tipo == role,
      orElse: () => Role(
        negocioId: 'rlAB6phw0EBsBFeDyOt6',
        tipo: role,
        nivelHierarquico: 50,
        nomeCustomizado: role,
        cor: '#9E9E9E',
        icone: 'person',
        permissions: [],
        isActive: true,
      ),
    );

    // Mapeia o nome do ícone para o IconData correspondente
    final iconName = customRole.icone ?? 'person';
    switch (iconName) {
      case 'person':
        return Icons.person_outline;
      case 'health_and_safety':
        return Icons.health_and_safety_outlined;
      case 'medical_services':
        return Icons.medical_services_outlined;
      case 'medical_information':
        return Icons.medical_information_outlined;
      case 'admin_panel_settings':
        return Icons.admin_panel_settings_outlined;
      case 'groups':
        return Icons.groups_outlined;
      case 'local_hospital':
        return Icons.local_hospital_outlined;
      case 'healing':
        return Icons.healing_outlined;
      case 'volunteer_activism':
        return Icons.volunteer_activism_outlined;
      case 'favorite':
        return Icons.favorite_outline;
      case 'psychology':
        return Icons.psychology_outlined;
      case 'elderly':
        return Icons.elderly_outlined;
      case 'accessible':
        return Icons.accessible_outlined;
      case 'support':
        return Icons.support_outlined;
      case 'people':
        return Icons.people_outline;
      default:
        return Icons.person_outline;
    }
  }

  IconData _getIconFromString(String? iconName) {
    switch (iconName) {
      case 'person':
        return Icons.person;
      case 'medical_services':
        return Icons.medical_services;
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'psychology':
        return Icons.psychology;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'spa':
        return Icons.spa;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'healing':
        return Icons.healing;
      case 'favorite':
        return Icons.favorite;
      case 'monitor_heart':
        return Icons.monitor_heart;
      case 'science':
        return Icons.science;
      case 'biotech':
        return Icons.biotech;
      case 'support_agent':
        return Icons.support_agent;
      case 'supervisor_account':
        return Icons.supervisor_account;
      case 'group':
        return Icons.group;
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'restaurant':
        return Icons.restaurant;
      case 'local_cafe':
        return Icons.local_cafe;
      default:
        return Icons.person;
    }
  }

  Color _getColorFromHex(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return Colors.grey;
    }
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  Future<void> _showDynamicAssociationDialog(
      Usuario patient, Role profile) async {
    const negocioId = "rlAB6phw0EBsBFeDyOt6";

    // Busca profissionais com esse perfil
    final professionals =
        _allUsers.where((u) => u.roles?[negocioId] == profile.tipo).toList();

    // IDs já associados
    // IDs já associados
    List<String> associatedIds =
        patient.getAssociatedProfessionals(profile.id!);

    // Fallback para campos legados se não houver associação dinâmica
    if (associatedIds.isEmpty) {
      if (profile.tipo == 'enfermeiro' && patient.enfermeiroId != null) {
        associatedIds = [patient.enfermeiroId!];
      } else if (profile.tipo == 'medico' && patient.medicoId != null) {
        associatedIds = [patient.medicoId!];
      } else if (profile.tipo == 'tecnico' && patient.tecnicosIds != null) {
        associatedIds = List.from(patient.tecnicosIds!);
      }
    }

    final List<String> selectedIds = List.from(associatedIds);

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(_getIconFromString(profile.icone),
                      color: _getColorFromHex(profile.cor)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Vincular ${profile.nomeCustomizado}')),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: professionals.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                            'Nenhum profissional encontrado com este perfil.'),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: professionals.length,
                        itemBuilder: (context, index) {
                          final professional = professionals[index];
                          final isSelected =
                              selectedIds.contains(professional.id);

                          return CheckboxListTile(
                            title: Text(
                                DisplayUtils.getUserDisplayName(professional)),
                            subtitle: Text(professional.email ?? ''),
                            value: isSelected,
                            secondary: ProfileAvatar(
                              imageUrl: professional.profileImage,
                              userName: professional.nome,
                              radius: 16,
                            ),
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  selectedIds.add(professional.id!);
                                } else {
                                  selectedIds.remove(professional.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                if (professionals.isNotEmpty)
                  TextButton(
                    child: const Text('Salvar'),
                    onPressed: () async {
                      if (patient.id == null) return;

                      final apiService =
                          Provider.of<ApiService>(context, listen: false);
                      try {
                        await apiService.managePatientAssociation(
                            patient.id!, profile.id!, selectedIds);

                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    '${profile.nomeCustomizado} atualizado com sucesso!')),
                          );
                          // Delay para dar tempo do backend processar
                          await Future.delayed(
                              const Duration(milliseconds: 500));
                          _reloadData();
                        }
                      } catch (e) {
                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erro ao atualizar: $e')),
                          );
                        }
                      }
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildUserCard(Usuario user, String userRole, bool isInactive) {
    final displayName = DisplayUtils.getUserDisplayName(user);
    final initials = _getUserInitials(user);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isInactive ? Colors.grey[200] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner de nome no topo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: isInactive
                    ? LinearGradient(
                        colors: [Colors.grey[400]!, Colors.grey[500]!])
                    : _getRoleGradient(userRole),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: Colors.white, size: 20),
                    onSelected: (value) {
                      if (value == 'change_role') {
                        _showChangeRoleDialog(user);
                      } else if (value.startsWith('manage_')) {
                        final profileId = value.replaceFirst('manage_', '');
                        final profile = _availableRoles
                            .firstWhere((r) => r.id == profileId);
                        _showDynamicAssociationDialog(user, profile);
                      } else if (value == 'inativar') {
                        _showUpdateStatusDialog(user, 'inativo');
                      } else if (value == 'reativar') {
                        _showUpdateStatusDialog(user, 'ativo');
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      final items = <PopupMenuEntry<String>>[];

                      if (isInactive) {
                        items.add(const PopupMenuItem<String>(
                          value: 'reativar',
                          child: Text('Reativar Usuário'),
                        ));
                      } else {
                        items.add(const PopupMenuItem<String>(
                          value: 'change_role',
                          child: Text('Alterar Papel'),
                        ));
                        items.add(const PopupMenuItem<String>(
                          value: 'inativar',
                          child: Text('Inativar Usuário',
                              style: TextStyle(color: Colors.red)),
                        ));
                        items.add(const PopupMenuDivider());

                        if (userRole == 'cliente') {
                          // Associações Dinâmicas (Inclui roles de sistema como Médico, Enfermeiro, Técnico)
                          final customProfiles = _availableRoles.toList();

                          if (customProfiles.isNotEmpty) {
                            // items.add(const PopupMenuDivider()); // REMOVIDO: Já existe um divider acima
                            items.add(const PopupMenuItem(
                              enabled: false,
                              child: Text('Gerenciar Vínculos',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ));

                            for (final profile in customProfiles) {
                              items.add(
                                PopupMenuItem(
                                  value: 'manage_${profile.id}',
                                  child: Row(
                                    children: [
                                      Icon(_getIconFromString(profile.icone),
                                          size: 18,
                                          color: _getColorFromHex(profile.cor)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(
                                              'Vincular ${profile.nomeCustomizado}')),
                                    ],
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      }
                      return items;
                    },
                  ),
                ],
              ),
            ),

            // Conteúdo do card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Papel com ícone
                    Row(
                      children: [
                        Icon(
                          _getRoleIcon(userRole),
                          size: 18,
                          color: isInactive
                              ? Colors.grey[600]
                              : _getRoleGradient(userRole).colors[1],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getDisplayRoleName(userRole),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isInactive
                                  ? Colors.grey[600]
                                  : Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Status inativo em linha separada
                    if (isInactive) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const SizedBox(width: 26), // Alinha com o texto acima
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'INATIVO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Informações de vínculos
                    if (userRole == 'cliente' && !isInactive) ...[
                      const SizedBox(height: 8),
                      _buildCardNurseInfo(user),
                      const SizedBox(height: 4),
                      _buildCardDoctorInfo(user),
                      const SizedBox(height: 4),
                      _buildCardTechniciansInfo(user),
                      const SizedBox(height: 8),
                    ] else ...[
                      const SizedBox(height: 12),
                    ],

                    // Avatar centralizado na parte inferior
                    Expanded(
                      child: Center(
                        child: ProfileAvatar(
                          imageUrl: user.profileImage,
                          userName: user.nome,
                          radius: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardNurseInfo(Usuario patient) {
    String nurseName = 'Sem enfermeiro';
    if (patient.enfermeiroId != null && patient.enfermeiroId!.isNotEmpty) {
      final nurse = _allUsers.firstWhere(
        (u) => u.profissional_id == patient.enfermeiroId,
        orElse: () => const Usuario(firebaseUid: '', id: null, email: null),
      );
      if (nurse.email != null) {
        nurseName =
            DisplayUtils.getUserDisplayName(nurse, fallback: 'Enfermeiro');
      }
    }

    return Row(
      children: [
        Icon(Icons.health_and_safety_outlined,
            size: 16, color: Colors.green[700]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            nurseName,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildCardDoctorInfo(Usuario patient) {
    String doctorName = 'Sem médico';
    if (patient.medicoId != null && patient.medicoId!.isNotEmpty) {
      final doctor = _allUsers.firstWhere(
        (u) => u.id == patient.medicoId,
        orElse: () => const Usuario(firebaseUid: '', id: null, email: null),
      );
      if (doctor.email != null) {
        doctorName =
            DisplayUtils.getUserDisplayName(doctor, fallback: 'Médico');
      }
    }

    return Row(
      children: [
        Icon(Icons.medical_information_outlined,
            size: 16, color: Colors.purple[700]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            doctorName,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildCardTechniciansInfo(Usuario patient) {
    final technicianIds = patient.tecnicosIds ?? [];
    String techniciansText;

    if (technicianIds.isEmpty) {
      techniciansText = 'Sem técnicos';
    } else {
      final technicianNames = technicianIds.map((id) {
        final tech = _allUsers.firstWhere(
          (u) => u.id == id,
          orElse: () =>
              const Usuario(firebaseUid: '', id: null, email: 'Desconhecido'),
        );
        return DisplayUtils.getUserDisplayName(tech, fallback: 'Técnico');
      }).toList();

      if (technicianNames.length == 1) {
        techniciansText = 'Téc: ${technicianNames.first}';
      } else {
        final firstTech = technicianNames.first;
        techniciansText = 'Téc: $firstTech +${technicianNames.length - 1}';
      }
    }

    return Row(
      children: [
        Icon(Icons.medical_services_outlined,
            size: 16, color: Colors.orange[700]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            techniciansText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
