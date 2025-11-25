// lib/screens/profile_settings_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import '../services/auth_service.dart';
import '../api/api_service.dart';
import '../core/theme/app_theme.dart';
import '../widgets/ygg_branding.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _numeroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _cepController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _showChangePassword = false;
  bool _isFetchingCep = false;
  bool _isLoadingUserData = false;
  Uint8List? _profileImageBytes;
  String? _selectedEstado;
  
  final _cepFormatter = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {'#': RegExp(r'[0-9]')},
  );
  
  // *** ADICIONADO: Lista de estados válidos ***
  final List<String> _estadosBrasileiros = [
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS',
    'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC',
    'SP', 'SE', 'TO'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _cepController.addListener(_onCepChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      authService.addListener(_onAuthServiceChanged);
    });
  }
  
  void _onAuthServiceChanged() {
    if (mounted) {
      _loadUserData();
    }
  }

  void _loadUserData() {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    
    if (user != null && mounted) {
      setState(() {
        _isLoadingUserData = true; 
        
        _nomeController.text = user.nome ?? '';
        _telefoneController.text = user.telefone ?? '';
        
        if (user.endereco != null) {
          _enderecoController.text = user.endereco?['rua'] ?? user.endereco?['logradouro'] ?? '';
          _numeroController.text = user.endereco?['numero'] ?? '';
          _cidadeController.text = user.endereco?['cidade'] ?? '';
          
          final estado = user.endereco?['estado'];
          _selectedEstado = (estado != null && estado.isNotEmpty) ? estado : null;

          final initialCep = user.endereco?['cep'] ?? '';
          if (initialCep.isNotEmpty) {
            _cepController.text = _cepFormatter.maskText(initialCep);
          }
        } else {
          _enderecoController.text = '';
          _numeroController.text = '';
          _cidadeController.text = '';
          _selectedEstado = null;
          _cepController.text = '';
        }
        
        _isLoadingUserData = false;
      });
    }
  }

  void _onCepChanged() {
    if (_isLoadingUserData) return;
    
    final unmaskedCep = _cepFormatter.getUnmaskedText();
    if (unmaskedCep.length == 8) {
      _fetchAddressFromCep(unmaskedCep);
    }
  }

  Future<void> _fetchAddressFromCep(String cep) async {
    setState(() => _isFetchingCep = true);
    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$cep/json/');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['erro'] != true) {
          setState(() {
            _enderecoController.text = data['logradouro'] ?? '';
            _cidadeController.text = data['localidade'] ?? '';
            _selectedEstado = data['uf'] ?? '';
          });
        } else {
          // *** CORREÇÃO APLICADA AQUI ***
          setState(() {
            _enderecoController.clear();
            _cidadeController.clear();
            _selectedEstado = null;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('CEP não encontrado. Por favor, digite manualmente.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao buscar CEP. Verifique sua conexão.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingCep = false);
      }
    }
  }

  Future<void> _pickAndEditImage() async {
    try {
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Escolher Foto'),
            content: const Text('De onde você gostaria de escolher a foto?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, ImageSource.camera),
                child: const Text('Câmera'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, ImageSource.gallery),
                child: const Text('Galeria'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      );

      if (source == null) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        if (mounted) {
          await _openImageEditor(bytes);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
    }
  }

  Future<void> _openImageEditor(Uint8List imageBytes) async {
    try {
      final editedImage = await Navigator.push<Uint8List?>(
        context,
        MaterialPageRoute(
          builder: (context) => ProImageEditor.memory(
            imageBytes,
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (bytes) async {
                Navigator.pop(context, bytes);
              },
            ),
            configs: const ProImageEditorConfigs(),
          ),
        ),
      );
      
      if (editedImage != null && mounted) {
        setState(() {
          _profileImageBytes = editedImage;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao editar imagem: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
  
    setState(() {
      _isLoading = true;
    });
  
    try {
      final authService = context.read<AuthService>();
      final apiService = ApiService(authService: authService);
  
      final updateData = <String, dynamic>{
        'nome': _nomeController.text.trim(),
        'telefone': _telefoneController.text.trim(),
      };
      
      if (_enderecoController.text.trim().isNotEmpty || 
          _numeroController.text.trim().isNotEmpty ||
          _cidadeController.text.trim().isNotEmpty ||
          _selectedEstado != null ||
          _cepController.text.trim().isNotEmpty) {
        updateData['endereco'] = {
          'rua': _enderecoController.text.trim(),
          'numero': _numeroController.text.trim(),
          'cidade': _cidadeController.text.trim(),
          'estado': _selectedEstado ?? '',
          'cep': _cepFormatter.getUnmaskedText(),
        };
      }
  
      final updatedUser = await apiService.updateUserProfile(updateData, imageBytes: _profileImageBytes);
      
      await authService.updateFirebaseProfile(displayName: _nomeController.text.trim());
  
      if (_showChangePassword &&
          _currentPasswordController.text.isNotEmpty &&
          _newPasswordController.text.isNotEmpty) {
        await authService.changePassword(
          _currentPasswordController.text,
          _newPasswordController.text,
        );
      }
  
      // Atualiza o AuthService com os dados mais recentes retornados pela API
      if (updatedUser != null) {
        authService.updateCurrentUserData(updatedUser);
      } else {
        await authService.refreshCurrentUser();
      }
      
      if (mounted) {
        _loadUserData();
      }
  
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar perfil: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildProfileImage() {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;

    if (_profileImageBytes != null) {
      return ClipOval(
        child: Image.memory(
          _profileImageBytes!,
          fit: BoxFit.cover,
          width: 120,
          height: 120,
        ),
      );
    }

    if (user?.profileImage != null && user!.profileImage!.isNotEmpty) {
      if (user.profileImage!.startsWith('data:image')) {
        try {
          final base64String = user.profileImage!.split(',').last;
          final bytes = base64.decode(base64String);
          return ClipOval(
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: 120,
              height: 120,
            ),
          );
        } catch (e) {
          // Se falhar ao decodificar, mostra ícone padrão
        }
      } else {
        final imageUrl = ApiService.buildImageUrl(user.profileImage);
        
        if (imageUrl.isNotEmpty) {
          return ClipOval(
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.person,
                  size: 60,
                  color: Colors.white,
                );
              },
            ),
          );
        }
      }
    }

    return const Icon(
      Icons.person,
      size: 60,
      color: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    // *** CORREÇÃO APLICADA AQUI ***
    // Garante que o valor do Dropdown seja sempre válido antes de construir
    final validSelectedEstado = _selectedEstado != null && _estadosBrasileiros.contains(_selectedEstado) 
        ? _selectedEstado 
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Configurações do Perfil',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickAndEditImage,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryBlue,
                          border: Border.all(
                            color: AppTheme.primaryBlueDark,
                            width: 3,
                          ),
                        ),
                        child: _buildProfileImage(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _pickAndEditImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Alterar Foto'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Informações Pessoais',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome Completo',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nome é obrigatório';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length < 10) {
                    return 'Telefone deve ter pelo menos 10 dígitos';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              const Text(
                'Endereço',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _cepController,
                decoration: InputDecoration(
                  labelText: 'CEP',
                  border: const OutlineInputBorder(),
                  suffixIcon: _isFetchingCep 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [_cepFormatter],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _enderecoController,
                      decoration: const InputDecoration(
                        labelText: 'Logradouro',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _numeroController,
                      decoration: const InputDecoration(
                        labelText: 'Número',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cidadeController,
                      decoration: const InputDecoration(
                        labelText: 'Cidade',
                        prefixIcon: Icon(Icons.location_city_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        border: OutlineInputBorder(),
                      ),
                      value: validSelectedEstado, // Usando a variável validada
                      items: _estadosBrasileiros.map((String estado) {
                        return DropdownMenuItem(value: estado, child: Text(estado));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedEstado = value;
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  const Text(
                    'Alterar Senha',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _showChangePassword,
                    onChanged: (value) {
                      setState(() {
                        _showChangePassword = value;
                        if (!value) {
                          _currentPasswordController.clear();
                          _newPasswordController.clear();
                          _confirmPasswordController.clear();
                        }
                      });
                    },
                    activeTrackColor: AppTheme.primaryBlue,
                  ),
                ],
              ),

              if (_showChangePassword) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _currentPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Senha Atual',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: _showChangePassword
                      ? (value) {
                          if (value == null || value.isEmpty) {
                            return 'Senha atual é obrigatória';
                          }
                          return null;
                        }
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Nova Senha',
                    prefixIcon: Icon(Icons.lock_outlined),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: _showChangePassword
                      ? (value) {
                          if (value == null || value.length < 6) {
                            return 'Nova senha deve ter pelo menos 6 caracteres';
                          }
                          return null;
                        }
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar Nova Senha',
                    prefixIcon: Icon(Icons.lock_outlined),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: _showChangePassword
                      ? (value) {
                          if (value != _newPasswordController.text) {
                            return 'Senhas não coincidem';
                          }
                          return null;
                        }
                      : null,
                ),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Salvar Alterações',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),
              
              // Ygg Branding
              const Center(
                child: YggBranding(
                  fontSize: 11,
                  padding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cepController.removeListener(_onCepChanged);
    
    try {
      final authService = context.read<AuthService>();
      authService.removeListener(_onAuthServiceChanged);
    } catch (e) {
      // Ignorar erro se o context não estiver mais disponível
    }
    
    _nomeController.dispose();
    _telefoneController.dispose();
    _enderecoController.dispose();
    _numeroController.dispose();
    _cidadeController.dispose();
    _cepController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}