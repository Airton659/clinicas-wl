import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../api/api_service.dart';

class ProfileAvatar extends StatefulWidget {
  final String? imageUrl;
  final String? userName;
  final double radius;
  final Uint8List? imageBytes;
  final VoidCallback? onTap;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.userName,
    this.radius = 20,
    this.imageBytes,
    this.onTap,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Uint8List? _imageBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeImage();
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Se a URL da imagem mudou, recarregar
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.imageBytes != widget.imageBytes) {
      _initializeImage();
    }
  }

  void _initializeImage() {
    if (widget.imageBytes != null) {
      setState(() {
        _imageBytes = widget.imageBytes;
        _isLoading = false;
      });
    } else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _imageBytes = null; // Limpar imagem anterior
      });
      _loadImage();
    } else {
      setState(() {
        _isLoading = false;
        _imageBytes = null; // Limpar imagem anterior
      });
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final fullUrl = ApiService.buildImageUrl(widget.imageUrl!);
      debugPrint('[ProfileAvatar] Tentando carregar imagem: $fullUrl');

      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {
          'Accept': 'image/*',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[ProfileAvatar] Timeout ao carregar: $fullUrl');
          throw Exception('Timeout');
        },
      );

      if (response.statusCode == 200 && mounted) {
        debugPrint('[ProfileAvatar] Imagem carregada com sucesso: ${response.bodyBytes.length} bytes');
        setState(() {
          _imageBytes = response.bodyBytes;
          _isLoading = false;
        });
      } else {
        debugPrint('[ProfileAvatar] Erro HTTP ${response.statusCode}: $fullUrl');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[ProfileAvatar] Erro ao carregar imagem: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getInitials() {
    if (widget.userName == null || widget.userName!.isEmpty) return '?';
    
    final words = widget.userName!.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return widget.userName![0].toUpperCase();
  }
  
  Color _getAvatarColor() {
    if (widget.userName == null || widget.userName!.isEmpty) return Colors.grey;
    
    final initials = _getInitials();
    final hash = initials.hashCode;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
    ];
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: _imageBytes == null ? _getAvatarColor() : Colors.grey[300],
        backgroundImage: _imageBytes != null ? MemoryImage(_imageBytes!) : null,
        child: _isLoading
            ? SizedBox(
                width: widget.radius * 0.8,
                height: widget.radius * 0.8,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : _imageBytes == null
                ? Text(
                    _getInitials(),
                    style: TextStyle(
                      fontSize: widget.radius * 0.6,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : null,
      ),
    );
  }
}