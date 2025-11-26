// lib/config/app_config.dart
// Configuração específica para Clínica Médica (concierge-health-pilot)

class AppConfig {
  // URL do backend API
  static const String apiBaseUrl = 'https://clinica-medica-backend-388995704994.southamerica-east1.run.app';

  // Nome do cliente (para exibição)
  static const String clientName = 'Clínica Médica';

  // ID do negócio no Firestore (específico por cliente)
  // TEMPORÁRIO: Usando ID do negócio de produção até criar um novo
  static const String negocioId = 'rlAB6phw0EBsBFeDyOt6';

  // Verifica se a configuração foi feita corretamente
  static bool get isConfigured {
    return !apiBaseUrl.contains('REPLACE') &&
           !clientName.contains('REPLACE') &&
           !negocioId.contains('REPLACE');
  }
}
