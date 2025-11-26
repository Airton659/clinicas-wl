#!/usr/bin/env python3
"""
Script para gerar chaves VAPID para Web Push Notifications
"""

import os
import sys

try:
    from py_vapid import Vapid
except ImportError:
    print("❌ Erro: py-vapid não está instalado.")
    print("Execute: pip3 install py-vapid")
    sys.exit(1)

def generate_vapid_keys():
    """Gera um par de chaves VAPID (pública e privada)"""

    print("🔑 Gerando chaves VAPID...\n")

    # Gera as chaves
    vapid = Vapid()
    vapid.generate_keys()

    # Extrai chaves em formato base64url (sem padding)
    private_key = vapid.private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption()
    )

    public_key_raw = vapid.public_key.public_bytes(
        encoding=serialization.Encoding.X962,
        format=serialization.PublicFormat.UncompressedPoint
    )

    # Converte para base64url
    import base64

    # Remove header do PEM e converte
    private_pem = private_key.decode('utf-8')
    private_lines = [line for line in private_pem.split('\n')
                     if not line.startswith('-----')]
    private_b64 = ''.join(private_lines)

    # Public key já está em formato raw bytes
    public_b64 = base64.urlsafe_b64encode(public_key_raw).decode('utf-8').rstrip('=')

    print("✅ Chaves VAPID geradas com sucesso!\n")
    print("=" * 80)
    print("VAPID_PRIVATE_KEY:")
    print(private_b64)
    print()
    print("VAPID_PUBLIC_KEY:")
    print(public_b64)
    print("=" * 80)
    print()
    print("📋 Próximos passos:")
    print("1. Adicione as chaves acima como variáveis de ambiente no Cloud Run")
    print("2. Ou adicione no arquivo config.yaml do cliente")
    print("3. Configure VAPID_CLAIMS_EMAIL (ex: mailto:suporte@seudominio.com)")

    return {
        'private_key': private_b64,
        'public_key': public_b64
    }

if __name__ == '__main__':
    from cryptography.hazmat.primitives import serialization
    generate_vapid_keys()
