// lib/utils/error_handler.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ErrorHandler {
  /// Converte erros do Firebase Auth em mensagens amigáveis
  static String getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-email':
      case 'invalid-credential':
        return 'Email ou senha incorretos. Verifique suas credenciais e tente novamente.';
      
      case 'user-disabled':
        return 'Esta conta foi desabilitada. Entre em contato com o suporte.';
      
      case 'too-many-requests':
        return 'Muitas tentativas de login. Aguarde alguns minutos e tente novamente.';
      
      case 'operation-not-allowed':
        return 'Login com email e senha não está habilitado. Contate o suporte.';
      
      case 'weak-password':
        return 'A senha é muito fraca. Use pelo menos 6 caracteres com letras e números.';
      
      case 'email-already-in-use':
        return 'Este email já está sendo usado por outra conta.';
      
      case 'requires-recent-login':
        return 'Para sua segurança, faça login novamente antes de alterar a senha.';
      
      case 'network-request-failed':
        return 'Problema de conexão. Verifique sua internet e tente novamente.';
      
      default:
        return 'Erro de autenticação. Tente novamente ou contate o suporte.';
    }
  }

  /// Converte erros de API HTTP em mensagens amigáveis
  static String getApiErrorMessage(http.Response response) {
    switch (response.statusCode) {
      case 400:
        return 'Dados inválidos. Verifique as informações e tente novamente.';
      
      case 401:
        return 'Sessão expirada. Faça login novamente.';
      
      case 403:
        return 'Você não tem permissão para realizar esta ação.';
      
      case 404:
        return 'Informação não encontrada. Tente atualizar a página.';
      
      case 422:
        return 'Dados incompletos ou inválidos. Verifique os campos obrigatórios.';
      
      case 429:
        return 'Muitas solicitações. Aguarde um momento e tente novamente.';
      
      case 500:
      case 502:
      case 503:
        return 'Problema temporário no servidor. Tente novamente em alguns minutos.';
      
      case 504:
        return 'Tempo limite esgotado. Verifique sua conexão e tente novamente.';
      
      default:
        return 'Erro inesperado. Tente novamente ou contate o suporte.';
    }
  }

  /// Converte exceções genéricas em mensagens amigáveis
  static String getGenericErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return getFirebaseAuthErrorMessage(error);
    }
    
    if (error.toString().contains('network') || 
        error.toString().contains('connection') ||
        error.toString().contains('timeout')) {
      return 'Problema de conexão. Verifique sua internet e tente novamente.';
    }
    
    if (error.toString().contains('permission') || 
        error.toString().contains('forbidden')) {
      return 'Você não tem permissão para realizar esta ação.';
    }
    
    if (error.toString().contains('not found') || 
        error.toString().contains('404')) {
      return 'Informação não encontrada. Tente atualizar a página.';
    }
    
    return 'Ocorreu um erro inesperado. Tente novamente ou contate o suporte.';
  }

  /// Mensagens específicas para operações comuns
  static const Map<String, String> operationMessages = {
    'login_failed': 'Falha no login. Verifique suas credenciais.',
    'password_change_success': 'Senha alterada com sucesso!',
    'password_change_failed': 'Erro ao alterar senha. Tente novamente.',
    'data_save_success': 'Informações salvas com sucesso!',
    'data_save_failed': 'Erro ao salvar. Verifique os dados e tente novamente.',
    'data_load_failed': 'Erro ao carregar informações. Tente atualizar a página.',
    'connection_error': 'Problema de conexão. Verifique sua internet.',
    'session_expired': 'Sessão expirada. Faça login novamente.',
    'permission_denied': 'Você não tem permissão para esta ação.',
    'validation_error': 'Verifique os campos obrigatórios e tente novamente.',
  };

  /// Retorna mensagem específica da operação
  static String getOperationMessage(String operation) {
    return operationMessages[operation] ?? 'Operação concluída.';
  }
}