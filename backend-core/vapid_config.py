# vapid_config.py
import os

# Chaves VAPID para Web Push (Lembretes de Exames)
# Formato: DER base64url (sem padding)
# IMPORTANTE: Estas chaves devem ser ÚNICAS por projeto Firebase
# Configure via variáveis de ambiente no Cloud Run

VAPID_PRIVATE_KEY = os.getenv('VAPID_PRIVATE_KEY', '')

VAPID_PUBLIC_KEY = os.getenv('VAPID_PUBLIC_KEY', '')

VAPID_CLAIMS_EMAIL = os.getenv('VAPID_CLAIMS_EMAIL', 'mailto:suporte@seusistema.com.br')

# Validação
if not VAPID_PRIVATE_KEY or not VAPID_PUBLIC_KEY:
    print("⚠️  WARNING: VAPID keys not configured. Web Push notifications will not work.")
    print("   Set VAPID_PRIVATE_KEY and VAPID_PUBLIC_KEY environment variables.")
