// NOVO ARQUIVO: lib/screens/patient_list_page.dart

import 'package:analicegrubert/api/api_service.dart';
import 'package:analicegrubert/models/usuario.dart';
import 'package:analicegrubert/models/role.dart';
import 'package:analicegrubert/screens/patient_details_page.dart';
import 'package:analicegrubert/core/widgets/modern_widgets.dart';
import 'package:analicegrubert/core/theme/app_theme.dart';
import 'package:analicegrubert/utils/display_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:analicegrubert/providers/permissions_provider.dart';

class PatientListPage extends StatefulWidget {
  final String? filterByMissingAssociation;

  const PatientListPage({
    super.key,
    this.filterByMissingAssociation,
  });

  @override
  State<PatientListPage> createState() => _PatientListPageState();
}

class _PatientListPageState extends State<PatientListPage> {
  late Future<List<Usuario>> _usersFuture;
  List<Usuario> _allPatients = [];
  List<Usuario> _filteredPatients = [];
  final TextEditingController _searchController = TextEditingController();
  List<Role> _customProfiles = [];

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _loadCustomProfiles();
    _searchController.addListener(_filterPatients);
  }

  void _loadPatients() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    const negocioId = "rlAB6phw0EBsBFeDyOt6";

    setState(() {
      _usersFuture = apiService.getAllUsersInBusiness().then((users) {
        // Filtra para pegar apenas os usuários com o papel de 'cliente' (pacientes)
        // Excluir super_admins
        final patients = users
            .where((user) =>
                !user.isSuperAdmin && user.roles?[negocioId] == 'cliente')
            .toList();

        _allPatients = patients;

        // Aplica filtro inicial se houver
        if (widget.filterByMissingAssociation != null) {
          _filteredPatients = patients
              .where((p) =>
                  p.getAssociationCount(widget.filterByMissingAssociation!) ==
                  0)
              .toList();
        } else {
          _filteredPatients = patients;
        }

        return _filteredPatients;
      });
    });
  }

  Future<void> _loadCustomProfiles() async {
    try {
      final permissionsProvider =
          Provider.of<PermissionsProvider>(context, listen: false);
      const negocioId = "rlAB6phw0EBsBFeDyOt6";

      await permissionsProvider.carregarRoles(negocioId);
      final profiles = permissionsProvider.negocioRoles;

      setState(() {
        // Filtra apenas perfis customizados (não system)
        _customProfiles = profiles.where((p) => !p.isSystem).toList();
      });
    } catch (e) {
      debugPrint('Erro ao carregar perfis customizados: $e');
    }
  }

  void _filterPatients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPatients = _allPatients.where((patient) {
        final name = patient.nome?.toLowerCase() ?? '';
        final email = patient.email?.toLowerCase() ?? '';
        return name.contains(query) || email.contains(query);
      }).toList();
    });
  }

  Future<void> _reloadData() async {
    final apiService = Provider.of<ApiService>(context, listen: false);

    // Feedback visual imediato
    setState(() {
      // Opcional: limpar a lista para mostrar que está recarregando
      _allPatients = [];
      _filteredPatients = [];
    });

    // Aguardar um momento para garantir que o backend processou
    await Future.delayed(const Duration(milliseconds: 1000));

    setState(() {
      _usersFuture =
          apiService.getAllUsersInBusiness(forceRefresh: true).then((users) {
        // Filtra para pegar apenas os usuários com o papel de 'cliente' (pacientes)
        // Excluir super_admins
        const negocioId = "rlAB6phw0EBsBFeDyOt6";
        final patients = users
            .where((user) =>
                !user.isSuperAdmin && user.roles?[negocioId] == 'cliente')
            .toList();

        _allPatients = patients;

        // Aplica filtro inicial se houver
        if (widget.filterByMissingAssociation != null) {
          _filteredPatients = patients
              .where((p) =>
                  p.getAssociationCount(widget.filterByMissingAssociation!) ==
                  0)
              .toList();
        } else {
          _filteredPatients = patients;
        }

        return _filteredPatients;
      });
    });
  }

  Widget _buildPatientCard(Usuario patient) {
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    final isInactive = patient.status_por_negocio?[negocioId] == 'inativo';
    final displayName = DisplayUtils.getUserDisplayName(patient);

    return ModernCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showPatientDetailsModal(patient),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header com avatar e informações principais
            Row(
              children: [
                // AQUI ESTÁ A CORREÇÃO:
                ModernAvatar(
                  name: displayName,
                  imageUrl: patient.profileImage, // Adicionado a URL da imagem
                  radius: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isInactive
                                    ? AppTheme.neutralGray500
                                    : AppTheme.neutralGray800,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (isInactive)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'INATIVO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.errorRed,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: isInactive
                                ? AppTheme.neutralGray400
                                : AppTheme.neutralGray500,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              patient.email ?? 'Email não informado',
                              style: TextStyle(
                                fontSize: 12,
                                color: isInactive
                                    ? AppTheme.neutralGray400
                                    : AppTheme.neutralGray500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: isInactive
                        ? AppTheme.neutralGray400
                        : AppTheme.neutralGray500,
                    size: 20,
                  ),
                  onSelected: (value) => _handleMenuAction(value, patient),
                  itemBuilder: (context) => _buildPatientMenuItems(patient),
                ),
              ],
            ),

            // Informações de vinculação (se houver)
            if (_hasLinkedProfessionals(patient)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.neutralGray50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.neutralGray200),
                ),
                child: _buildLinkedProfessionals(patient, isInactive),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasLinkedProfessionals(Usuario patient) {
    return (patient.enfermeiroId != null && patient.enfermeiroId!.isNotEmpty) ||
        (patient.medicoId != null && patient.medicoId!.isNotEmpty) ||
        (patient.tecnicosIds != null && patient.tecnicosIds!.isNotEmpty);
  }

  Widget _buildLinkedProfessionals(Usuario patient, bool isInactive) {
    final List<Widget> professionals = [];

    if (patient.enfermeiroId != null && patient.enfermeiroId!.isNotEmpty) {
      professionals.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isInactive
                    ? AppTheme.neutralGray200
                    : AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.health_and_safety_outlined,
                size: 14,
                color:
                    isInactive ? AppTheme.neutralGray400 : AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Enfermeiro vinculado',
              style: TextStyle(
                fontSize: 12,
                color:
                    isInactive ? AppTheme.neutralGray400 : AppTheme.primaryBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (patient.medicoId != null && patient.medicoId!.isNotEmpty) {
      if (professionals.isNotEmpty) {
        professionals.add(const SizedBox(height: 8));
      }
      professionals.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isInactive
                    ? AppTheme.neutralGray200
                    : const Color(0xFF9C27B0).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.medical_information_outlined,
                size: 14,
                color: isInactive
                    ? AppTheme.neutralGray400
                    : const Color(0xFF9C27B0),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Médico vinculado',
              style: TextStyle(
                fontSize: 12,
                color: isInactive
                    ? AppTheme.neutralGray400
                    : const Color(0xFF9C27B0),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (patient.tecnicosIds != null && patient.tecnicosIds!.isNotEmpty) {
      if (professionals.isNotEmpty) {
        professionals.add(const SizedBox(height: 8));
      }
      professionals.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isInactive
                    ? AppTheme.neutralGray200
                    : AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.medical_services_outlined,
                size: 14,
                color: isInactive
                    ? AppTheme.neutralGray400
                    : AppTheme.successGreen,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${patient.tecnicosIds!.length} técnico${patient.tecnicosIds!.length > 1 ? 's' : ''} vinculado${patient.tecnicosIds!.length > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: isInactive
                    ? AppTheme.neutralGray400
                    : AppTheme.successGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Badges dinâmicos para cada perfil customizado
    for (final profile in _customProfiles) {
      final associatedCount = patient.getAssociationCount(profile.id!);

      if (associatedCount > 0) {
        if (professionals.isNotEmpty) {
          professionals.add(const SizedBox(height: 8));
        }

        professionals.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isInactive
                      ? AppTheme.neutralGray200
                      : _getColorFromHex(profile.cor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _getIconFromString(profile.icone),
                  size: 14,
                  color: isInactive
                      ? AppTheme.neutralGray400
                      : _getColorFromHex(profile.cor),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$associatedCount ${profile.nomeCustomizado}${associatedCount > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: isInactive
                      ? AppTheme.neutralGray400
                      : _getColorFromHex(profile.cor),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: professionals,
    );
  }

  void _handleMenuAction(String action, Usuario patient) {
    if (action.startsWith('manage_')) {
      final profileId = action.substring(7); // Remove 'manage_'
      final profile = _customProfiles.firstWhere((p) => p.id == profileId);
      _showDynamicAssociationDialog(patient, profile);
      return;
    }

    switch (action) {
      case 'view_patient':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientDetailsPage(
              pacienteId: patient.id!,
              pacienteNome: patient.nome,
            ),
          ),
        );
        break;
    }
  }

  List<PopupMenuEntry<String>> _buildPatientMenuItems(Usuario patient) {
    final List<PopupMenuEntry<String>> items = [
      const PopupMenuItem<String>(
        value: 'view_patient',
        child: Row(
          children: [
            Icon(Icons.visibility_outlined, size: 18),
            SizedBox(width: 12),
            Text('Visualizar Paciente'),
          ],
        ),
      ),
    ];

    // Seção de associações dinâmicas
    if (_customProfiles.isNotEmpty) {
      items.add(const PopupMenuDivider());
      items.add(const PopupMenuItem<String>(
        enabled: false,
        child: Text(
          'Gerenciar Vínculos',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppTheme.neutralGray600,
          ),
        ),
      ));

      for (final profile in _customProfiles) {
        items.add(
          PopupMenuItem<String>(
            value: 'manage_${profile.id}',
            child: Row(
              children: [
                Icon(
                  _getIconFromString(profile.icone),
                  size: 18,
                  color: _getColorFromHex(profile.cor),
                ),
                const SizedBox(width: 12),
                Text('Vincular ${profile.nomeCustomizado}'),
              ],
            ),
          ),
        );
      }
    }

    return items;
  }

  Future<void> _showDynamicAssociationDialog(
      Usuario patient, Role profile) async {
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    final apiService = Provider.of<ApiService>(context, listen: false);

    // Buscar usuários que têm esse perfil
    final allUsers = await apiService.getAllUsersInBusiness();
    final professionals = allUsers
        .where((user) => user.roles?[negocioId] == profile.tipo)
        .toList();

    // IDs já associados
    List<String> selectedIds =
        List.from(patient.getAssociatedProfessionals(profile.id!));

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Vincular ${profile.nomeCustomizado}'),
              content: SizedBox(
                width: double.maxFinite,
                child: professionals.isEmpty
                    ? const Text(
                        'Nenhum profissional disponível com este perfil.')
                    : ListView(
                        shrinkWrap: true,
                        children: professionals.map((user) {
                          final isSelected = selectedIds.contains(user.id);
                          return CheckboxListTile(
                            title: Text(user.nome ?? user.email ?? 'Sem nome'),
                            subtitle:
                                user.email != null ? Text(user.email!) : null,
                            value: isSelected,
                            onChanged: (bool? selected) {
                              setDialogState(() {
                                if (selected == true) {
                                  selectedIds.add(user.id!);
                                } else {
                                  selectedIds.remove(user.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Salvar'),
                  onPressed: () async {
                    if (patient.id == null) return;

                    try {
                      await apiService.managePatientAssociation(
                        patient.id!,
                        profile.id!,
                        selectedIds,
                      );

                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${selectedIds.length} ${profile.nomeCustomizado}(s) associado(s)!'),
                          ),
                        );
                        await _reloadData();
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro: $e')),
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
      case 'restaurant':
        return Icons.restaurant;
      case 'spa':
        return Icons.spa;
      case 'healing':
        return Icons.healing;
      case 'monitor_heart':
        return Icons.monitor_heart;
      case 'science':
        return Icons.science;
      default:
        return Icons.person;
    }
  }

  Color _getColorFromHex(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return AppTheme.primaryBlue;
    }

    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return AppTheme.primaryBlue;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos os Pacientes'),
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
          Expanded(
            child: FutureBuilder<List<Usuario>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text(
                          'Erro ao carregar pacientes: ${snapshot.error}'));
                }
                if (_filteredPatients.isEmpty) {
                  return const Center(
                      child: Text('Nenhum paciente encontrado.'));
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadPatients(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredPatients.length,
                    itemBuilder: (context, index) {
                      final patient = _filteredPatients[index];
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 600 + (index * 50)),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(50 * (1 - value), 0),
                            child: Opacity(
                              opacity: value,
                              child: _buildPatientCard(patient),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPatientDetailsModal(Usuario patient) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _PatientDetailsModal(patient: patient),
    );

    if (result == 'details') {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatientDetailsPage(
            pacienteId: patient.id!,
            pacienteNome: patient.nome ?? patient.email,
          ),
        ),
      );
      // Recarrega a lista após voltar da tela de detalhes
      if (mounted) {
        _reloadData();
      }
    }
  }
}

class _PatientDetailsModal extends StatefulWidget {
  final Usuario patient;

  const _PatientDetailsModal({required this.patient});

  @override
  State<_PatientDetailsModal> createState() => _PatientDetailsModalState();
}

class _PatientDetailsModalState extends State<_PatientDetailsModal> {
  Usuario? assignedNurse;
  List<Usuario> assignedTechnicians = [];
  Usuario? assignedDoctor;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignedProfessionals();
  }

  Future<void> _loadAssignedProfessionals() async {
    setState(() => isLoading = true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final allUsers = await apiService.getAllUsersInBusiness();
      const negocioId = "rlAB6phw0EBsBFeDyOt6";

      // Buscar profissional - usar a mesma lógica do team management
      if (widget.patient.enfermeiroId != null &&
          widget.patient.enfermeiroId!.isNotEmpty) {
        try {
          assignedNurse = allUsers.firstWhere(
            (user) => user.profissional_id == widget.patient.enfermeiroId,
            orElse: () => const Usuario(firebaseUid: '', id: null, email: null),
          );
          if (assignedNurse?.email != null) {
          } else {
            assignedNurse = null;
          }
        } catch (e) {
          assignedNurse = null;
        }
      }

      // Buscar técnicos - usar a mesma lógica do team management
      if (widget.patient.tecnicosIds?.isNotEmpty == true) {
        assignedTechnicians = [];
        for (String techId in widget.patient.tecnicosIds!) {
          try {
            final tech = allUsers.firstWhere(
              (user) => user.id == techId,
              orElse: () => const Usuario(
                  firebaseUid: '', id: null, email: 'Desconhecido'),
            );
            if (tech.email != null && tech.email != 'Desconhecido') {
              assignedTechnicians.add(tech);
            }
          } catch (e) {}
        }
      } else {}

      // Buscar médico
      if (widget.patient.medicoId != null &&
          widget.patient.medicoId!.isNotEmpty) {
        try {
          assignedDoctor = allUsers.firstWhere(
            (user) => user.id == widget.patient.medicoId,
            orElse: () => const Usuario(firebaseUid: '', id: null, email: null),
          );
          if (assignedDoctor?.email != null) {
          } else {
            assignedDoctor = null;
          }
        } catch (e) {
          assignedDoctor = null;
        }
      } else {}
    } catch (e) {
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppTheme.neutralGray200),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.neutralGray300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryBlue, AppTheme.accentTeal],
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.patient.nome ??
                                  widget.patient.email ??
                                  'Paciente',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.neutralGray800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.patient.email ?? 'Email não informado',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.neutralGray600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context, 'details');
                        },
                        child: const Text('Ver detalhes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildProfessionalsSection(),
                      ],
                    ),
            ),
          ],
        ));
  }

  Widget _buildProfessionalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profissionais Associados',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.neutralGray800,
          ),
        ),
        const SizedBox(height: 16),

        // Enfermeiro
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: assignedNurse != null
                ? AppTheme.successGreen.withOpacity(0.1)
                : AppTheme.errorRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: assignedNurse != null
                  ? AppTheme.successGreen.withOpacity(0.3)
                  : AppTheme.errorRed.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: assignedNurse != null
                      ? AppTheme.successGreen
                      : AppTheme.errorRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  assignedNurse != null
                      ? Icons.local_hospital
                      : Icons.person_off,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profissional Responsável',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.neutralGray600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      assignedNurse?.nome ??
                          assignedNurse?.email ??
                          'Nenhum profissional associado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: assignedNurse != null
                            ? AppTheme.successGreen
                            : AppTheme.errorRed,
                      ),
                    ),
                    if (assignedNurse?.email != null &&
                        assignedNurse?.nome != null)
                      Text(
                        assignedNurse!.email!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.neutralGray500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Técnicos
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: assignedTechnicians.isNotEmpty
                ? AppTheme.primaryBlue.withOpacity(0.1)
                : AppTheme.warningOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: assignedTechnicians.isNotEmpty
                  ? AppTheme.primaryBlue.withOpacity(0.3)
                  : AppTheme.warningOrange.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: assignedTechnicians.isNotEmpty
                          ? AppTheme.primaryBlue
                          : AppTheme.warningOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      assignedTechnicians.isNotEmpty
                          ? Icons.groups
                          : Icons.person_off,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Técnicos Associados',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.neutralGray600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          assignedTechnicians.isNotEmpty
                              ? '${assignedTechnicians.length} técnico${assignedTechnicians.length > 1 ? 's' : ''} associado${assignedTechnicians.length > 1 ? 's' : ''}'
                              : 'Nenhum técnico associado',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: assignedTechnicians.isNotEmpty
                                ? AppTheme.primaryBlue
                                : AppTheme.warningOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (assignedTechnicians.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...assignedTechnicians.map((tech) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tech.nome ?? tech.email ?? 'Técnico sem nome',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.neutralGray800,
                                  ),
                                ),
                                if (tech.email != null && tech.nome != null)
                                  Text(
                                    tech.email!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.neutralGray500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Médico
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: assignedDoctor != null
                ? const Color(0xFF9C27B0).withOpacity(0.1)
                : AppTheme.neutralGray200.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: assignedDoctor != null
                  ? const Color(0xFF9C27B0).withOpacity(0.3)
                  : AppTheme.neutralGray400.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: assignedDoctor != null
                      ? const Color(0xFF9C27B0)
                      : AppTheme.neutralGray400,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  assignedDoctor != null
                      ? Icons.medical_services
                      : Icons.person_off,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Médico Responsável',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.neutralGray600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      assignedDoctor?.nome ??
                          assignedDoctor?.email ??
                          'Nenhum médico associado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: assignedDoctor != null
                            ? const Color(0xFF9C27B0)
                            : AppTheme.neutralGray400,
                      ),
                    ),
                    if (assignedDoctor?.email != null &&
                        assignedDoctor?.nome != null)
                      Text(
                        assignedDoctor!.email!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.neutralGray500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
