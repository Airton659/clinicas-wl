// NOVO ARQUIVO: lib/screens/patient_list_page.dart

import 'package:analicegrubert/api/api_service.dart';
import 'package:analicegrubert/models/usuario.dart';
import 'package:analicegrubert/screens/patient_details_page.dart';
import 'package:analicegrubert/core/widgets/modern_widgets.dart';
import 'package:analicegrubert/core/theme/app_theme.dart';
import 'package:analicegrubert/utils/display_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PatientListPage extends StatefulWidget {
  const PatientListPage({super.key});

  @override
  State<PatientListPage> createState() => _PatientListPageState();
}

class _PatientListPageState extends State<PatientListPage> {
  late Future<List<Usuario>> _usersFuture;
  List<Usuario> _allPatients = [];
  List<Usuario> _filteredPatients = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _searchController.addListener(_filterPatients);
  }

  void _loadPatients() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    const negocioId = "rlAB6phw0EBsBFeDyOt6";

    setState(() {
      _usersFuture = apiService.getAllUsersInBusiness().then((users) {
        // Filtra para pegar apenas os usuários com o papel de 'cliente' (pacientes)
        // Excluir super_admins
        final patients = users.where((user) =>
          !user.isSuperAdmin && user.roles?[negocioId] == 'cliente'
        ).toList();
        _allPatients = patients;
        _filteredPatients = patients;
        return patients;
      });
    });
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
    
    // Aguardar um momento para garantir que o backend processou
    await Future.delayed(const Duration(milliseconds: 300));
    
    setState(() {
      _usersFuture = apiService.getAllUsersInBusiness(forceRefresh: true).then((users) {
        // Filtra para pegar apenas os usuários com o papel de 'cliente' (pacientes)
        // Excluir super_admins
        const negocioId = "rlAB6phw0EBsBFeDyOt6";
        final patients = users.where((user) =>
          !user.isSuperAdmin && user.roles?[negocioId] == 'cliente'
        ).toList();
        _allPatients = patients;
        _filteredPatients = patients;
        return patients;
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
                              color: isInactive ? AppTheme.neutralGray500 : AppTheme.neutralGray800,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (isInactive)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          color: isInactive ? AppTheme.neutralGray400 : AppTheme.neutralGray500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            patient.email ?? 'Email não informado',
                            style: TextStyle(
                              fontSize: 12,
                              color: isInactive ? AppTheme.neutralGray400 : AppTheme.neutralGray500,
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
                  color: isInactive ? AppTheme.neutralGray400 : AppTheme.neutralGray500,
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
                color: isInactive ? AppTheme.neutralGray200 : AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.health_and_safety_outlined,
                size: 14,
                color: isInactive ? AppTheme.neutralGray400 : AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Enfermeiro vinculado',
              style: TextStyle(
                fontSize: 12,
                color: isInactive ? AppTheme.neutralGray400 : AppTheme.primaryBlue,
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
                color: isInactive ? AppTheme.neutralGray200 : const Color(0xFF9C27B0).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.medical_information_outlined,
                size: 14,
                color: isInactive ? AppTheme.neutralGray400 : const Color(0xFF9C27B0),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Médico vinculado',
              style: TextStyle(
                fontSize: 12,
                color: isInactive ? AppTheme.neutralGray400 : const Color(0xFF9C27B0),
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
                color: isInactive ? AppTheme.neutralGray200 : AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.medical_services_outlined,
                size: 14,
                color: isInactive ? AppTheme.neutralGray400 : AppTheme.successGreen,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${patient.tecnicosIds!.length} técnico${patient.tecnicosIds!.length > 1 ? 's' : ''} vinculado${patient.tecnicosIds!.length > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: isInactive ? AppTheme.neutralGray400 : AppTheme.successGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: professionals,
    );
  }

  void _handleMenuAction(String action, Usuario patient) {
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
      case 'link_nurse':
        _showLinkNurseDialog(patient);
        break;
      case 'unlink_nurse':
        _unlinkNurse(patient);
        break;
      case 'link_doctor':
        _showLinkDoctorDialog(patient);
        break;
      case 'unlink_doctor':
        _unlinkDoctor(patient);
        break;
      case 'link_technicians':
        _showLinkTechniciansDialog(patient);
        break;
      case 'unlink_technicians':
        _unlinkTechnicians(patient);
        break;
    }
  }

  List<PopupMenuEntry<String>> _buildPatientMenuItems(Usuario patient) {
    final hasNurse = patient.enfermeiroId != null && patient.enfermeiroId!.isNotEmpty;
    final hasTechnicians = patient.tecnicosIds != null && patient.tecnicosIds!.isNotEmpty;
    final hasDoctor = patient.medicoId != null && patient.medicoId!.isNotEmpty;
    
    return [
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
      const PopupMenuDivider(),
      if (!hasNurse)
        const PopupMenuItem<String>(
          value: 'link_nurse',
          child: Row(
            children: [
              Icon(Icons.health_and_safety_outlined, size: 18, color: AppTheme.primaryBlue),
              SizedBox(width: 12),
              Text('Associar Enfermeiro'),
            ],
          ),
        )
      else
        const PopupMenuItem<String>(
          value: 'unlink_nurse',
          child: Row(
            children: [
              Icon(Icons.link_off_outlined, size: 18, color: AppTheme.errorRed),
              SizedBox(width: 12),
              Text('Desassociar Enfermeiro'),
            ],
          ),
        ),
      if (!hasDoctor)
        const PopupMenuItem<String>(
          value: 'link_doctor',
          child: Row(
            children: [
              Icon(Icons.medical_information_outlined, size: 18, color: Color(0xFF9C27B0)),
              SizedBox(width: 12),
              Text('Associar Médico'),
            ],
          ),
        )
      else
        const PopupMenuItem<String>(
          value: 'unlink_doctor',
          child: Row(
            children: [
              Icon(Icons.link_off_outlined, size: 18, color: AppTheme.errorRed),
              SizedBox(width: 12),
              Text('Desassociar Médico'),
            ],
          ),
        ),
      const PopupMenuItem<String>(
        value: 'link_technicians',
        child: Row(
          children: [
            Icon(Icons.medical_services_outlined, size: 18, color: AppTheme.successGreen),
            SizedBox(width: 12),
            Text('Associar Técnicos'),
          ],
        ),
      ),
      if (hasTechnicians)
        const PopupMenuItem<String>(
          value: 'unlink_technicians',
          child: Row(
            children: [
              Icon(Icons.link_off_outlined, size: 18, color: AppTheme.errorRed),
              SizedBox(width: 12),
              Text('Desassociar Técnicos'),
            ],
          ),
        ),
    ];
  }

  Future<void> _showLinkNurseDialog(Usuario patient) async {
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    // Buscar todos os enfermeiros disponíveis
    final allUsers = await apiService.getAllUsersInBusiness();
    final nurses = allUsers.where((user) => user.roles?[negocioId] == 'profissional' && user.profissional_id != null).toList();
    
    String? selectedNurseId = patient.enfermeiroId;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Vincular Enfermeiro para ${patient.nome ?? patient.email}'),
              content: DropdownButtonFormField<String>(
                value: selectedNurseId,
                hint: const Text('Selecione um Enfermeiro'),
                isExpanded: true,
                items: nurses.map((Usuario nurse) {
                  return DropdownMenuItem<String>(
                    value: nurse.profissional_id,
                    child: Text(nurse.nome ?? nurse.email ?? 'Enfermeiro sem nome'),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setDialogState(() {
                    selectedNurseId = newValue;
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
                    if (patient.id == null || selectedNurseId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Erro: Selecione um enfermeiro.')),
                      );
                      return;
                    }

                    final apiService = Provider.of<ApiService>(context, listen: false);
                    try {
                      await apiService.linkPatientToNurse(patient.id!, selectedNurseId!);
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enfermeiro vinculado com sucesso!')),
                        );
                        await _reloadData(); // Recarregar lista
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao vincular enfermeiro: $e')),
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

  Future<void> _showLinkTechniciansDialog(Usuario patient) async {
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    // Buscar todos os técnicos disponíveis
    final allUsers = await apiService.getAllUsersInBusiness();
    final technicians = allUsers.where((user) => user.roles?[negocioId] == 'tecnico').toList();
    
    List<String> selectedTechnicianIds = List.from(patient.tecnicosIds ?? []);

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Associar Técnicos para ${patient.nome ?? patient.email}'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: technicians.map((Usuario tech) {
                    final isSelected = selectedTechnicianIds.contains(tech.id);
                    return CheckboxListTile(
                      title: Text(tech.nome ?? tech.email ?? 'Técnico sem nome'),
                      subtitle: tech.email != null ? Text(tech.email!) : null,
                      value: isSelected,
                      onChanged: (bool? selected) {
                        setDialogState(() {
                          if (selected == true) {
                            selectedTechnicianIds.add(tech.id!);
                          } else {
                            selectedTechnicianIds.remove(tech.id);
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
                    if (patient.id == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Erro: Paciente inválido.')),
                      );
                      return;
                    }

                    final apiService = Provider.of<ApiService>(context, listen: false);
                    try {
                      await apiService.linkTechniciansToPatient(patient.id!, selectedTechnicianIds);
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${selectedTechnicianIds.length} técnico(s) associado(s) com sucesso!')),
                        );
                        await _reloadData(); // Recarregar lista
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao associar técnicos: $e')),
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

  Future<bool> _showUnlinkConfirmationDialog({required String title, required String content}) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirmar')),
        ],
      ),
    ) ?? false;
  }

  Future<void> _unlinkNurse(Usuario patient) async {
    final confirmed = await _showUnlinkConfirmationDialog(
      title: 'Desvincular Enfermeiro',
      content: 'Tem certeza que deseja desvincular o enfermeiro deste paciente?',
    );
    if (!confirmed || patient.id == null) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      await apiService.linkPatientToNurse(patient.id!, null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enfermeiro desvinculado com sucesso!')),
        );
        await _reloadData(); // Recarregar lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao desvincular: $e')),
        );
      }
    }
  }

  Future<void> _unlinkTechnicians(Usuario patient) async {
    final confirmed = await _showUnlinkConfirmationDialog(
      title: 'Desvincular Técnicos',
      content: 'Tem certeza que deseja desvincular todos os técnicos deste paciente?',
    );
    if (!confirmed || patient.id == null) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      await apiService.linkTechniciansToPatient(patient.id!, []); // Lista vazia para desvincular todos
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Técnicos desvinculados com sucesso!')),
        );
        await _reloadData(); // Recarregar lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao desvincular: $e')),
        );
      }
    }
  }

  Future<void> _showLinkDoctorDialog(Usuario patient) async {
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    // Buscar todos os médicos disponíveis
    final allUsers = await apiService.getAllUsersInBusiness();
    final doctors = allUsers.where((user) => user.roles?[negocioId] == 'medico').toList();
    
    String? selectedDoctorId = patient.medicoId;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Associar Médico para ${patient.nome ?? patient.email}'),
              content: DropdownButtonFormField<String>(
                value: selectedDoctorId,
                hint: const Text('Selecione um Médico'),
                isExpanded: true,
                items: doctors.map((Usuario doctor) {
                  return DropdownMenuItem<String>(
                    value: doctor.id,
                    child: Text(doctor.nome ?? doctor.email ?? 'Médico sem nome'),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setDialogState(() {
                    selectedDoctorId = newValue;
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
                    if (patient.id == null || selectedDoctorId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Erro: Selecione um médico.')),
                      );
                      return;
                    }

                    final apiService = Provider.of<ApiService>(context, listen: false);
                    try {
                      await apiService.linkPatientToDoctor(patient.id!, selectedDoctorId!);
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Médico vinculado com sucesso!')),
                        );
                        await _reloadData(); // Recarregar lista
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao vincular médico: $e')),
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

  Future<void> _unlinkDoctor(Usuario patient) async {
    final confirmed = await _showUnlinkConfirmationDialog(
      title: 'Desvincular Médico',
      content: 'Tem certeza que deseja desvincular o médico deste paciente?',
    );
    if (!confirmed || patient.id == null) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      await apiService.linkPatientToDoctor(patient.id!, null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Médico desvinculado com sucesso!')),
        );
        await _reloadData(); // Recarregar lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao desvincular: $e')),
        );
      }
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
                  return Center(child: Text('Erro ao carregar pacientes: ${snapshot.error}'));
                }
                if (_filteredPatients.isEmpty) {
                  return const Center(child: Text('Nenhum paciente encontrado.'));
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


  Widget _buildAssociationStatus(Usuario patient) {
    final hasNurse = patient.enfermeiroId != null;
    final hasTechnicians = patient.tecnicosIds?.isNotEmpty == true;
    final techCount = patient.tecnicosIds?.length ?? 0;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: hasNurse ? AppTheme.successGreen.withOpacity(0.1) : AppTheme.errorRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasNurse ? Icons.check_circle : Icons.person_off,
                size: 12,
                color: hasNurse ? AppTheme.successGreen : AppTheme.errorRed,
              ),
              const SizedBox(width: 4),
              Text(
                hasNurse ? 'Profissional' : 'Sem profissional',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: hasNurse ? AppTheme.successGreen : AppTheme.errorRed,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: hasTechnicians ? AppTheme.primaryBlue.withOpacity(0.1) : AppTheme.warningOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasTechnicians ? Icons.groups : Icons.person_off,
                size: 12,
                color: hasTechnicians ? AppTheme.primaryBlue : AppTheme.warningOrange,
              ),
              const SizedBox(width: 4),
              Text(
                hasTechnicians ? '$techCount técnico${techCount > 1 ? 's' : ''}' : 'Sem técnicos',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: hasTechnicians ? AppTheme.primaryBlue : AppTheme.warningOrange,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPatientDetailsModal(Usuario patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _PatientDetailsModal(patient: patient),
    );
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
      if (widget.patient.enfermeiroId != null && widget.patient.enfermeiroId!.isNotEmpty) {
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
              orElse: () => const Usuario(firebaseUid: '', id: null, email: 'Desconhecido'),
            );
            if (tech.email != null && tech.email != 'Desconhecido') {
              assignedTechnicians.add(tech);
            }
          } catch (e) {
          }
        }
      } else {
      }

      // Buscar médico
      if (widget.patient.medicoId != null && widget.patient.medicoId!.isNotEmpty) {
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
      } else {
      }
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
                                widget.patient.nome ?? widget.patient.email ?? 'Paciente',
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
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PatientDetailsPage(
                                  pacienteId: widget.patient.id!,
                                  pacienteNome: widget.patient.nome ?? widget.patient.email,
                                ),
                              ),
                            );
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
            color: assignedNurse != null ? AppTheme.successGreen.withOpacity(0.1) : AppTheme.errorRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: assignedNurse != null ? AppTheme.successGreen.withOpacity(0.3) : AppTheme.errorRed.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: assignedNurse != null ? AppTheme.successGreen : AppTheme.errorRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  assignedNurse != null ? Icons.local_hospital : Icons.person_off,
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
                      assignedNurse?.nome ?? assignedNurse?.email ?? 'Nenhum profissional associado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: assignedNurse != null ? AppTheme.successGreen : AppTheme.errorRed,
                      ),
                    ),
                    if (assignedNurse?.email != null && assignedNurse?.nome != null)
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
            color: assignedTechnicians.isNotEmpty ? AppTheme.primaryBlue.withOpacity(0.1) : AppTheme.warningOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: assignedTechnicians.isNotEmpty ? AppTheme.primaryBlue.withOpacity(0.3) : AppTheme.warningOrange.withOpacity(0.3),
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
                      color: assignedTechnicians.isNotEmpty ? AppTheme.primaryBlue : AppTheme.warningOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      assignedTechnicians.isNotEmpty ? Icons.groups : Icons.person_off,
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
                            color: assignedTechnicians.isNotEmpty ? AppTheme.primaryBlue : AppTheme.warningOrange,
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
            color: assignedDoctor != null ? const Color(0xFF9C27B0).withOpacity(0.1) : AppTheme.neutralGray200.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: assignedDoctor != null ? const Color(0xFF9C27B0).withOpacity(0.3) : AppTheme.neutralGray400.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: assignedDoctor != null ? const Color(0xFF9C27B0) : AppTheme.neutralGray400,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  assignedDoctor != null ? Icons.medical_services : Icons.person_off,
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
                      assignedDoctor?.nome ?? assignedDoctor?.email ?? 'Nenhum médico associado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: assignedDoctor != null ? const Color(0xFF9C27B0) : AppTheme.neutralGray400,
                      ),
                    ),
                    if (assignedDoctor?.email != null && assignedDoctor?.nome != null)
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