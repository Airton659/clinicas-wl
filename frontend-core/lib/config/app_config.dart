// lib/config/app_config.dart
// Este arquivo define a configuração do app por cliente
// IMPORTANTE: Este arquivo é SUBSTITUÍDO por cliente no processo de deploy

class AppConfig {
  // URL do backend API
  static const String apiBaseUrl = 'REPLACE_API_BASE_URL';

  // Nome do cliente (para exibição)
  static const String clientName = 'REPLACE_CLIENT_NAME';

  // ID do negócio no Firestore (específico por cliente)
  static const String negocioId = 'REPLACE_NEGOCIO_ID';

  // Verifica se a configuração foi feita corretamente
  static bool get isConfigured {
    return !apiBaseUrl.contains('REPLACE') &&
           !clientName.contains('REPLACE') &&
           !negocioId.contains('REPLACE');
  }
}
