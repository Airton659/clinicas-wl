// lib/utils/display_utils.dart

import '../models/usuario.dart';
import '../models/diario.dart';

class DisplayUtils {
  /// Retorna o nome de exibição preferencial do usuário
  /// Prioridade: nome completo > primeira parte do email > fallback
  static String getUserDisplayName(Usuario user, {String fallback = 'Usuário'}) {
    if (user.nome != null && user.nome!.trim().isNotEmpty) {
      return user.nome!.trim();
    }
    if (user.email != null && user.email!.trim().isNotEmpty) {
      return user.email!.split('@').first;
    }
    return fallback;
  }
  
  /// Retorna o subtítulo apropriado (email ou informação adicional)
  static String getUserSubtitle(Usuario user, {bool showExtendedInfo = false}) {
    final email = user.email?.trim() ?? 'Email não informado';
    
    if (!showExtendedInfo) {
      return email;
    }
    
    // Para admins/gestores, mostra informações adicionais se disponíveis
    final List<String> infos = [email];
    
    if (user.telefone != null && user.telefone!.trim().isNotEmpty) {
      infos.add('Tel: ${user.telefone!.trim()}');
    }
    
    if (user.endereco != null && 
        user.endereco!['logradouro'] != null && 
        user.endereco!['logradouro'].toString().trim().isNotEmpty) {
      infos.add('End: ${user.endereco!['logradouro'].toString().trim()}');
    }
    
    return infos.join(' • ');
  }
  
  /// Versão específica para técnicos (usado em chips e filtros)
  static String getTecnicoDisplayName(Usuario tecnico) {
    return getUserDisplayName(tecnico, fallback: 'Técnico');
  }
  
  /// Para diálogos e títulos formais
  static String getFormalDisplayName(Usuario user) {
    final name = getUserDisplayName(user);
    final email = user.email?.trim();
    
    // Se temos nome e email, mostra "Nome (email)"
    if (user.nome != null && user.nome!.trim().isNotEmpty && email != null) {
      return '$name ($email)';
    }
    return name;
  }
  
  /// Versão específica para o modelo Tecnico (do diário)
  static String getTecnicoDisplayNameFromTecnico(Tecnico tecnico) {
    if (tecnico.nome.trim().isNotEmpty && tecnico.nome != 'Desconhecido') {
      return tecnico.nome.trim();
    }
    if (tecnico.email.trim().isNotEmpty && tecnico.email != 'Desconhecido') {
      return tecnico.email.split('@').first;
    }
    return 'Técnico';
  }
}