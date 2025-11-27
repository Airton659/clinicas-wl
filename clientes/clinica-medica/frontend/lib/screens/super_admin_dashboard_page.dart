import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/negocio.dart';
import '../services/super_admin_service.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import 'terminology_editor_page.dart';

/// Dashboard para Super Admins (role="platform")
/// Permite visualizar todos os negócios e gerenciar terminologias
class SuperAdminDashboardPage extends StatefulWidget {
  const SuperAdminDashboardPage({Key? key}) : super(key: key);

  @override
  State<SuperAdminDashboardPage> createState() =>
      _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage> {
  late SuperAdminService _superAdminService;
  List<Negocio> _negocios = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  void _initializeService() {
    final authService = context.read<AuthService>();
    _superAdminService = SuperAdminService(
      baseUrl: AppConfig.apiBaseUrl,
      getToken: () => authService.getIdToken(),
    );
    _loadNegocios();
  }

  Future<void> _loadNegocios() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final negocios = await _superAdminService.listNegocios();
      setState(() {
        _negocios = negocios;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: Colors.amber),
            SizedBox(width: 8),
            Text('Super Admin Dashboard'),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNegocios,
            tooltip: 'Recarregar',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _showAuditLogs,
            tooltip: 'Logs de Auditoria',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar negócios',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadNegocios,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );
    }

    if (_negocios.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Nenhum negócio encontrado'),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildStats(),
        Expanded(child: _buildNegociosList()),
      ],
    );
  }

  Widget _buildStats() {
    final totalNegocios = _negocios.length;
    final totalUsuarios =
        _negocios.fold<int>(0, (sum, n) => sum + (n.totalUsuarios ?? 0));
    final totalPacientes =
        _negocios.fold<int>(0, (sum, n) => sum + (n.totalPacientes ?? 0));

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.deepPurple.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(
            icon: Icons.business,
            label: 'Negócios',
            value: totalNegocios.toString(),
            color: Colors.blue,
          ),
          _buildStatCard(
            icon: Icons.people,
            label: 'Usuários',
            value: totalUsuarios.toString(),
            color: Colors.green,
          ),
          _buildStatCard(
            icon: Icons.folder_shared,
            label: 'Pacientes',
            value: totalPacientes.toString(),
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildNegociosList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _negocios.length,
      itemBuilder: (context, index) {
        final negocio = _negocios[index];
        return _buildNegocioCard(negocio);
      },
    );
  }

  Widget _buildNegocioCard(Negocio negocio) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: negocio.ativo ? Colors.green : Colors.red,
          child: Icon(
            _getIconForTipo(negocio.tipo),
            color: Colors.white,
          ),
        ),
        title: Text(
          negocio.nome,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_getTipoLabel(negocio.tipo)} • Plano: ${negocio.plano}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  icon: Icons.calendar_today,
                  label: 'Criado em',
                  value: _formatDate(negocio.createdAt),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  icon: Icons.people,
                  label: 'Usuários',
                  value: '${negocio.totalUsuarios ?? 0}',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  icon: Icons.folder_shared,
                  label: 'Pacientes',
                  value: '${negocio.totalPacientes ?? 0}',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  icon: Icons.toggle_on,
                  label: 'Status',
                  value: negocio.ativo ? 'Ativo' : 'Inativo',
                  valueColor: negocio.ativo ? Colors.green : Colors.red,
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _editTerminology(negocio),
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar Terminologia'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _viewAuditLogs(negocio),
                      icon: const Icon(Icons.history),
                      label: const Text('Ver Logs'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  IconData _getIconForTipo(String tipo) {
    switch (tipo) {
      case 'clinica-vet':
        return Icons.pets;
      case 'clinica-medica':
        return Icons.local_hospital;
      case 'fisioterapia':
        return Icons.fitness_center;
      case 'psicologia':
        return Icons.psychology;
      default:
        return Icons.business;
    }
  }

  String _getTipoLabel(String tipo) {
    switch (tipo) {
      case 'clinica-vet':
        return 'Clínica Veterinária';
      case 'clinica-medica':
        return 'Clínica Médica';
      case 'fisioterapia':
        return 'Fisioterapia';
      case 'psicologia':
        return 'Psicologia';
      default:
        return tipo;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _editTerminology(Negocio negocio) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TerminologyEditorPage(
          negocio: negocio,
          superAdminService: _superAdminService,
        ),
      ),
    ).then((_) => _loadNegocios());
  }

  void _viewAuditLogs(Negocio negocio) async {
    try {
      final logs = await _superAdminService.getAuditLogs(
        negocioId: negocio.id,
        limit: 50,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Logs de Auditoria - ${negocio.nome}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: logs.isEmpty
                ? const Center(child: Text('Nenhum log encontrado'))
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return ListTile(
                        leading: const Icon(Icons.history, size: 20),
                        title: Text(log.action),
                        subtitle: Text(
                          '${log.adminEmail}\n${_formatDateTime(log.timestamp)}',
                        ),
                        isThreeLine: true,
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar logs: $e')),
      );
    }
  }

  void _showAuditLogs() async {
    try {
      final logs = await _superAdminService.getAuditLogs(limit: 100);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Todos os Logs de Auditoria'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: logs.isEmpty
                ? const Center(child: Text('Nenhum log encontrado'))
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.history, size: 20),
                          title: Text(log.action),
                          subtitle: Text(
                            '${log.adminEmail}\nNegócio: ${log.negocioId}\n${_formatDateTime(log.timestamp)}',
                          ),
                          isThreeLine: true,
                          dense: true,
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar logs: $e')),
      );
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
