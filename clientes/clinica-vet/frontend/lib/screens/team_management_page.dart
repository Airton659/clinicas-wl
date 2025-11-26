// lib/screens/team_management_page.dart

import 'package:analicegrubert/api/api_service.dart';
import 'package:analicegrubert/models/usuario.dart';
import 'package:analicegrubert/utils/display_utils.dart';
import '../widgets/profile_avatar.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String? _activeRoleFilter;
  String _statusFilter = 'ativo'; // O padrão continua sendo 'ativo'

  @override
  void initState() {
    super.initState();
    _activeRoleFilter = widget.initialRoleFilter;
    _fetchAndCacheUsers();
    _searchController.addListener(_filterUsers);
  }

  void _fetchAndCacheUsers({bool forceRefresh = false}) {
    print('📡 TeamManagementPage: _fetchAndCacheUsers chamado (forceRefresh: $forceRefresh)');
    final apiService = Provider.of<ApiService>(context, listen: false);

    // Otimização: Só busca 'todos' se o filtro for 'Todos' ou 'Inativos'
    final apiStatusFilter = (_statusFilter == 'ativo') ? 'ativo' : 'all';

    setState(() {
      _usersFuture = apiService.getAllUsersInBusiness(
        status: apiStatusFilter,
        forceRefresh: forceRefresh,
      ).then((users) {
        print('📥 TeamManagementPage: Recebidos ${users.length} usuários da API');
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
    print('   showOnlyPatientsWithoutTechnician: ${widget.showOnlyPatientsWithoutTechnician}');

    setState(() {
      _filteredUsers = _allUsers.where((user) {
        // Excluir super_admins da lista de equipe
        if (user.isSuperAdmin) return false;

        // Filtro por Papel
        final userRole = user.roles?[negocioId];
        final roleMatch = _activeRoleFilter == null || userRole == _activeRoleFilter;
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
          final hasNoNurse = user.enfermeiroId == null || user.enfermeiroId!.isEmpty;
          if (!isPatient || !hasNoNurse) {
            return false;
          }
        }

        // Filtro específico: "Pacientes sem Técnico"
        if (widget.showOnlyPatientsWithoutTechnician == true) {
          final isPatient = user.roles?[negocioId] == 'cliente';
          // CORREÇÃO: Verificar se o próprio paciente tem técnicos vinculados
          final pacienteTemTecnico = user.tecnicosIds != null && user.tecnicosIds!.isNotEmpty;

          print('   🏥 Paciente ${user.nome}: isPatient=$isPatient, temTecnico=$pacienteTemTecnico');
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
          final hasNoSupervisor = user.supervisor_id == null || user.supervisor_id!.isEmpty;
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

      print('📊 TeamManagementPage: Filtro final - ${_filteredUsers.length} usuários exibidos');
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
        return 'sem-papel';
    }
  }

  Future<void> _showChangeRoleDialog(Usuario user) async {
    // *** CORREÇÃO APLICADA AQUI ***
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    String? selectedRole = user.roles?[negocioId] ?? 'cliente';
    final rolesDisponiveis = ['profissional', 'tecnico', 'medico', 'cliente'];

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
                    final apiService = Provider.of<ApiService>(context, listen: false);
                    try {
                      await apiService.updateUserRole(user.id!, selectedRole!);
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Papel alterado com sucesso!')),
                        );
                                        _reloadData();
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao alterar o papel: $e')),
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
    final content = 'Tem certeza que deseja ${isActivating ? 'reativar' : 'inativar'} o usuário ${user.email}?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(isActivating ? 'Reativar' : 'Inativar')),
        ],
      ),
    ) ?? false;

    if (confirmed && mounted) {
      if (user.id == null) return;
      final apiService = Provider.of<ApiService>(context, listen: false);
      try {
        await apiService.updateUserStatus(user.id!, newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuário ${isActivating ? 'reativado' : 'inativado'} com sucesso!')),
        );
        _reloadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar status: $e')),
        );
      }
    }
  }

  Future<void> _showLinkSupervisorDialog(Usuario technician) async {
    // *** CORREÇÃO APLICADA AQUI ***
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    final supervisors = _allUsers.where((user) => user.roles?[negocioId] == 'profissional').toList();
    String? selectedSupervisorId = technician.supervisor_id;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Vincular Supervisor para ${technician.email}'),
              content: DropdownButtonFormField<String>(
                value: selectedSupervisorId,
                hint: const Text('Selecione um Enfermeiro'),
                isExpanded: true,
                items: supervisors.map((Usuario supervisor) {
                  return DropdownMenuItem<String>(
                    value: supervisor.id,
                    child: Text(supervisor.email ?? 'Supervisor sem email'),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setDialogState(() {
                    selectedSupervisorId = newValue;
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
                    if (technician.id == null || selectedSupervisorId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Erro: Selecione um supervisor.')),
                      );
                      return;
                    }

                    final apiService = Provider.of<ApiService>(context, listen: false);
                    try {
                      await apiService.linkSupervisorToTechnician(technician.id!, selectedSupervisorId!);
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Supervisor vinculado com sucesso!')),
                        );
                        // Delay para dar tempo do backend processar
                        await Future.delayed(const Duration(milliseconds: 500));
                        _reloadData();
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao vincular supervisor: $e')),
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
    // *** CORREÇÃO APLICADA AQUI ***
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    final technicians = _allUsers.where((user) => user.roles?[negocioId] == 'tecnico').toList();
    final List<String> selectedTechnicianIds = List<String>.from(patient.tecnicosIds ?? []); 

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Vincular Técnicos para ${patient.email}'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: technicians.length,
                  itemBuilder: (context, index) {
                    final technician = technicians[index];
                    return CheckboxListTile(
                      title: Text(technician.email ?? 'Técnico sem email'),
                      value: selectedTechnicianIds.contains(technician.id),
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            selectedTechnicianIds.add(technician.id!);
                          } else {
                            selectedTechnicianIds.remove(technician.id);
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
                TextButton(
                  child: const Text('Salvar'),
                  onPressed: () async {
                    if (patient.id == null) return;
                    
                    final apiService = Provider.of<ApiService>(context, listen: false);
                    try {
                      print('🔗 TeamManagementPage: Vinculando técnicos ao paciente ${patient.nome}');
                      print('   Paciente ID: ${patient.id}');
                      print('   Técnicos selecionados: $selectedTechnicianIds');

                      await apiService.linkTechniciansToPatient(patient.id!, selectedTechnicianIds);
                      print('✅ TeamManagementPage: Vinculação concluída no backend');

                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Técnicos vinculados com sucesso!')),
                        );
                        // Delay para dar tempo do backend processar
                        print('⏳ TeamManagementPage: Aguardando 500ms...');
                        await Future.delayed(const Duration(milliseconds: 500));
                        print('🔄 TeamManagementPage: Chamando _reloadData...');
                        _reloadData();
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao vincular técnicos: $e')),
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

  Future<void> _showLinkNurseDialog(Usuario patient) async {
    // *** CORREÇÃO APLICADA AQUI ***
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    final nurses = _allUsers.where((user) => user.roles?[negocioId] == 'profissional' && user.profissional_id != null).toList();
    
    String? selectedNurseId = patient.enfermeiroId;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Vincular Enfermeiro para ${patient.email}'),
              content: DropdownButtonFormField<String>(
                value: selectedNurseId,
                hint: const Text('Selecione um Enfermeiro'),
                isExpanded: true,
                items: nurses.map((Usuario nurse) {
                  return DropdownMenuItem<String>(
                    value: nurse.profissional_id,
                    child: Text(nurse.email ?? 'Enfermeiro sem email'),
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
                        // Delay para dar tempo do backend processar
                        await Future.delayed(const Duration(milliseconds: 500));
                        _reloadData();
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

  Future<void> _showLinkDoctorDialog(Usuario patient) async {
    // *** CORREÇÃO APLICADA AQUI ***
    const negocioId = "rlAB6phw0EBsBFeDyOt6";
    final doctors = _allUsers.where((user) => user.roles?[negocioId] == 'medico').toList();
    
    String? selectedDoctorId = patient.medicoId;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Vincular Médico para ${patient.email}'),
              content: DropdownButtonFormField<String>(
                value: selectedDoctorId,
                hint: const Text('Selecione um Médico'),
                isExpanded: true,
                items: doctors.map((Usuario doctor) {
                  return DropdownMenuItem<String>(
                    value: doctor.id,
                    child: Text(doctor.email ?? 'Médico sem email'),
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
                        // Delay para dar tempo do backend processar
                        await Future.delayed(const Duration(milliseconds: 500));
                        _reloadData();
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

  Future<void> _unlinkSupervisor(Usuario technician) async {
    final confirmed = await _showUnlinkConfirmationDialog(
      title: 'Desvincular Supervisor',
      content: 'Tem certeza que deseja desvincular o supervisor deste técnico?',
    );
    if (!confirmed || technician.id == null) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      await apiService.linkSupervisorToTechnician(technician.id!, null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supervisor desvinculado com sucesso!')));
        // Delay para dar tempo do backend processar
        await Future.delayed(const Duration(milliseconds: 500));
        _reloadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao desvincular: $e')));
    }
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enfermeiro desvinculado com sucesso!')));
        // Delay para dar tempo do backend processar
        await Future.delayed(const Duration(milliseconds: 500));
        _reloadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao desvincular: $e')));
    }
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Médico desvinculado com sucesso!')));
        // Delay para dar tempo do backend processar
        await Future.delayed(const Duration(milliseconds: 500));
        _reloadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao desvincular: $e')));
    }
  }

  Future<void> _unlinkAllTechnicians(Usuario patient) async {
    final confirmed = await _showUnlinkConfirmationDialog(
      title: 'Desvincular Todos os Técnicos',
      content: 'Tem certeza que deseja desvincular TODOS os técnicos deste paciente?',
    );
    if (!confirmed || patient.id == null) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      await apiService.linkTechniciansToPatient(patient.id!, []); // Envia lista vazia
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Técnicos desvinculados com sucesso!')));
        // Delay para dar tempo do backend processar
        await Future.delayed(const Duration(milliseconds: 500));
        // Delay para dar tempo do backend processar
        await Future.delayed(const Duration(milliseconds: 500));
        _reloadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao desvincular: $e')));
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
                const Text('Filtrar por Papel:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      FilterChip(
                        label: const Text('Pacientes'),
                        selected: _activeRoleFilter == 'cliente',
                        onSelected: (selected) => _setRoleFilter('cliente'),
                      ),
                      FilterChip(
                        label: const Text('Enfermeiros'),
                        selected: _activeRoleFilter == 'profissional',
                        onSelected: (selected) => _setRoleFilter('profissional'),
                      ),
                      FilterChip(
                        label: const Text('Técnicos'),
                        selected: _activeRoleFilter == 'tecnico',
                        onSelected: (selected) => _setRoleFilter('tecnico'),
                      ),
                      FilterChip(
                        label: const Text('Médicos'),
                        selected: _activeRoleFilter == 'medico',
                        onSelected: (selected) => _setRoleFilter('medico'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Filtrar por Status:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  return Center(child: Text('Erro ao carregar usuários: ${snapshot.error}'));
                }
                if (_filteredUsers.isEmpty) {
                  return const Center(child: Text('Nenhum usuário encontrado para os filtros aplicados.'));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 
                                   MediaQuery.of(context).size.width > 600 ? 3 : 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    final userRole = user.roles?[negocioId] ?? 'sem-papel';
                    final isInactive = user.status_por_negocio?[negocioId] == 'inativo';
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
    switch (role) {
      case 'cliente':
        return const LinearGradient(
          colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'profissional':
        return const LinearGradient(
          colors: [Color(0xFF66BB6A), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'tecnico':
        return const LinearGradient(
          colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'medico':
        return const LinearGradient(
          colors: [Color(0xFF9C27B0), Color(0xFF8E24AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'admin':
        return const LinearGradient(
          colors: [Color(0xFFE57373), Color(0xFFEF5350)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFFBDBDBD), Color(0xFF9E9E9E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  String _getUserInitials(Usuario user) {
    final displayName = DisplayUtils.getUserDisplayName(user);
    if (displayName.length >= 2) {
      return displayName.substring(0, 2).toUpperCase();
    }
    return displayName.substring(0, 1).toUpperCase();
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'cliente':
        return Icons.person_outline;
      case 'profissional':
        return Icons.health_and_safety_outlined;
      case 'tecnico':
        return Icons.medical_services_outlined;
      case 'medico':
        return Icons.medical_information_outlined;
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.help_outline;
    }
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
                gradient: isInactive ? 
                  LinearGradient(colors: [Colors.grey[400]!, Colors.grey[500]!]) :
                  _getRoleGradient(userRole),
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
                    icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                    onSelected: (value) {
                      if (value == 'change_role') {
                        _showChangeRoleDialog(user);
                      } else if (value == 'link_supervisor') {
                        _showLinkSupervisorDialog(user);
                      } else if (value == 'link_technicians') {
                        _showLinkTechniciansDialog(user);
                      } else if (value == 'link_nurse') {
                        _showLinkNurseDialog(user);
                      } else if (value == 'link_doctor') {
                        _showLinkDoctorDialog(user);
                      } 
                      else if (value == 'unlink_supervisor') {
                        _unlinkSupervisor(user);
                      } else if (value == 'unlink_nurse') {
                        _unlinkNurse(user);
                      } else if (value == 'unlink_doctor') {
                        _unlinkDoctor(user);
                      } else if (value == 'unlink_all_technicians') {
                        _unlinkAllTechnicians(user);
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
                          child: Text('Inativar Usuário', style: TextStyle(color: Colors.red)),
                        ));
                        items.add(const PopupMenuDivider());

                        if (userRole == 'tecnico') {
                          items.add(
                            const PopupMenuItem<String>(
                              value: 'link_supervisor',
                              child: Text('Vincular Supervisor'),
                            ),
                          );
                          if (user.supervisor_id != null && user.supervisor_id!.isNotEmpty) {
                            items.add(
                              const PopupMenuItem<String>(
                                value: 'unlink_supervisor',
                                child: Text('Desvincular Supervisor', style: TextStyle(color: Colors.red)),
                              ),
                            );
                          }
                        }
                        if (userRole == 'cliente') {
                          items.add(
                            const PopupMenuItem<String>(
                              value: 'link_technicians',
                              child: Text('Vincular Técnicos'),
                            ),
                          );
                          items.add(
                            const PopupMenuItem<String>(
                              value: 'link_nurse',
                              child: Text('Vincular Enfermeiro'),
                            ),
                          );
                          items.add(
                            const PopupMenuItem<String>(
                              value: 'link_doctor',
                              child: Text('Vincular Médico'),
                            ),
                          );
                          if ((user.enfermeiroId != null && user.enfermeiroId!.isNotEmpty) || 
                              (user.medicoId != null && user.medicoId!.isNotEmpty) ||
                              (user.tecnicosIds != null && user.tecnicosIds!.isNotEmpty)) {
                            items.add(const PopupMenuDivider());
                          }
                          if (user.enfermeiroId != null && user.enfermeiroId!.isNotEmpty) {
                            items.add(
                              const PopupMenuItem<String>(
                                value: 'unlink_nurse',
                                child: Text('Desvincular Enfermeiro', style: TextStyle(color: Colors.red)),
                              ),
                            );
                          }
                          if (user.medicoId != null && user.medicoId!.isNotEmpty) {
                            items.add(
                              const PopupMenuItem<String>(
                                value: 'unlink_doctor',
                                child: Text('Desvincular Médico', style: TextStyle(color: Colors.red)),
                              ),
                            );
                          }
                          if (user.tecnicosIds != null && user.tecnicosIds!.isNotEmpty) {
                            items.add(
                              const PopupMenuItem<String>(
                                value: 'unlink_all_technicians',
                                child: Text('Desvincular Todos os Técnicos', style: TextStyle(color: Colors.red)),
                              ),
                            );
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
                          color: isInactive ? Colors.grey[600] : _getRoleGradient(userRole).colors[1],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getDisplayRoleName(userRole),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isInactive ? Colors.grey[600] : Colors.grey[800],
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        nurseName = DisplayUtils.getUserDisplayName(nurse, fallback: 'Enfermeiro');
      }
    }

    return Row(
      children: [
        Icon(Icons.health_and_safety_outlined, size: 16, color: Colors.green[700]),
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
        doctorName = DisplayUtils.getUserDisplayName(doctor, fallback: 'Médico');
      }
    }

    return Row(
      children: [
        Icon(Icons.medical_information_outlined, size: 16, color: Colors.purple[700]),
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
          orElse: () => const Usuario(firebaseUid: '', id: null, email: 'Desconhecido'),
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
        Icon(Icons.medical_services_outlined, size: 16, color: Colors.orange[700]),
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