// lib/utils/image_picker_wrapper.dart
// Wrapper para image_picker que funciona tanto em web quanto em mobile

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Wrapper para ImagePicker que garante compatibilidade entre web e mobile
class ImagePickerWrapper {
  final ImagePicker _picker = ImagePicker();

  /// Pick uma imagem da galeria ou câmera
  ///
  /// No web, sempre usa a galeria (file picker)
  /// No mobile, permite escolher entre galeria e câmera
  Future<XFile?> pickImage({
    required ImageSource source,
    int? imageQuality,
    double? maxWidth,
    double? maxHeight,
  }) async {
    try {
      // No web, ImageSource.camera não funciona, então força galeria
      final effectiveSource = kIsWeb ? ImageSource.gallery : source;

      return await _picker.pickImage(
        source: effectiveSource,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
    } catch (e) {
      debugPrint('Erro ao selecionar imagem: $e');
      return null;
    }
  }

  /// Pick múltiplas imagens (apenas galeria)
  Future<List<XFile>> pickMultipleImages({
    int? imageQuality,
    double? maxWidth,
    double? maxHeight,
  }) async {
    try {
      return await _picker.pickMultiImage(
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
    } catch (e) {
      debugPrint('Erro ao selecionar múltiplas imagens: $e');
      return [];
    }
  }

  /// Mostra um dialog para o usuário escolher entre câmera e galeria
  ///
  /// No web, pula o dialog e vai direto para galeria
  static Future<ImageSource?> showImageSourceDialog(context) async {
    if (kIsWeb) {
      // No web, sempre retorna galeria
      return ImageSource.gallery;
    }

    // No mobile, mostra as opções
    return await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecione a origem'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }
}
