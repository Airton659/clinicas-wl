#!/usr/bin/env python3
"""
Script de teste para verificar a configuração multi-project Firebase.
Executa testes locais antes do deploy em produção.
"""

import os
import sys
import json

def test_imports():
    """Testa se todos os imports necessários estão disponíveis."""
    print("🔍 Testando imports...")
    try:
        import firebase_admin
        from firebase_admin import credentials, auth, firestore
        from google.cloud import secretmanager
        print("✅ Todos os imports OK")
        return True
    except ImportError as e:
        print(f"❌ Erro de import: {e}")
        return False

def test_secret_manager_connection():
    """Testa conexão com o Secret Manager."""
    print("\n🔍 Testando conexão com Secret Manager...")
    try:
        from google.cloud import secretmanager

        project_id = os.getenv("GCP_PROJECT_ID", "teste-notificacao-barbearia")
        client = secretmanager.SecretManagerServiceClient()

        # Lista os segredos disponíveis
        parent = f"projects/{project_id}"
        secrets = list(client.list_secrets(request={"parent": parent}))

        secret_names = [s.name.split('/')[-1] for s in secrets]
        print(f"✅ Conectado ao Secret Manager")
        print(f"   Segredos encontrados: {secret_names}")

        # Verifica se os segredos necessários existem
        required_secrets = ["firebase-admin-credentials", "firebase-admin-credentials-pilot"]
        missing_secrets = [s for s in required_secrets if s not in secret_names]

        if missing_secrets:
            print(f"⚠️  AVISO: Segredos faltando: {missing_secrets}")
            print("   O sistema funcionará apenas com o projeto original.")
        else:
            print("✅ Todos os segredos necessários estão presentes")

        return True
    except Exception as e:
        print(f"❌ Erro ao conectar com Secret Manager: {e}")
        print("   Certifique-se de que GOOGLE_APPLICATION_CREDENTIALS está configurado")
        return False

def test_firebase_initialization():
    """Testa a inicialização dos apps Firebase."""
    print("\n🔍 Testando inicialização Firebase...")
    try:
        from database import initialize_firebase_app, firebase_apps

        # Inicializa o Firebase
        initialize_firebase_app()

        print(f"✅ Firebase inicializado com {len(firebase_apps)} projeto(s)")
        for project_id, app_name in firebase_apps.items():
            print(f"   - {project_id} → app '{app_name}'")

        return True
    except Exception as e:
        print(f"❌ Erro ao inicializar Firebase: {e}")
        return False

def test_token_validation():
    """
    Testa a validação de tokens (requer tokens válidos).
    Este teste só funciona se você tiver um token válido para testar.
    """
    print("\n🔍 Testando validação de tokens...")

    # Verifica se há um token de teste
    test_token = os.getenv("TEST_FIREBASE_TOKEN")
    if not test_token:
        print("⏭️  Pulando: Nenhum token de teste fornecido")
        print("   Para testar, defina TEST_FIREBASE_TOKEN com um token válido")
        return True

    try:
        import firebase_admin
        from firebase_admin import auth
        from database import firebase_apps

        # Tenta validar o token com o app padrão
        try:
            decoded = auth.verify_id_token(test_token)
            print(f"✅ Token validado com app DEFAULT")
            print(f"   UID: {decoded.get('uid')}")
            return True
        except Exception as e:
            print(f"⚠️  Token não validou com app DEFAULT: {e}")

            # Tenta com os outros apps
            for project_id, app_name in firebase_apps.items():
                if app_name == "[DEFAULT]":
                    continue

                try:
                    app = firebase_admin.get_app(app_name)
                    decoded = auth.verify_id_token(test_token, app=app)
                    print(f"✅ Token validado com app '{app_name}'")
                    print(f"   UID: {decoded.get('uid')}")
                    return True
                except:
                    continue

            print("❌ Token não validou em nenhum app")
            return False

    except Exception as e:
        print(f"❌ Erro ao testar validação: {e}")
        return False

def test_code_syntax():
    """Verifica se os arquivos Python têm sintaxe válida."""
    print("\n🔍 Verificando sintaxe dos arquivos...")

    files_to_check = ["database.py", "auth.py", "main.py"]
    all_ok = True

    for filename in files_to_check:
        try:
            with open(filename, 'r') as f:
                compile(f.read(), filename, 'exec')
            print(f"✅ {filename} - sintaxe OK")
        except SyntaxError as e:
            print(f"❌ {filename} - ERRO DE SINTAXE: {e}")
            all_ok = False
        except FileNotFoundError:
            print(f"⚠️  {filename} - arquivo não encontrado")

    return all_ok

def main():
    """Executa todos os testes."""
    print("=" * 60)
    print("🧪 TESTE DE CONFIGURAÇÃO MULTI-PROJECT FIREBASE")
    print("=" * 60)

    # Verifica variáveis de ambiente
    print("\n📋 Variáveis de ambiente:")
    print(f"   GCP_PROJECT_ID: {os.getenv('GCP_PROJECT_ID', 'não definido')}")
    print(f"   GOOGLE_APPLICATION_CREDENTIALS: {os.getenv('GOOGLE_APPLICATION_CREDENTIALS', 'não definido')}")

    results = []

    # Executa os testes
    results.append(("Sintaxe dos arquivos", test_code_syntax()))
    results.append(("Imports", test_imports()))
    results.append(("Secret Manager", test_secret_manager_connection()))
    results.append(("Inicialização Firebase", test_firebase_initialization()))
    results.append(("Validação de tokens", test_token_validation()))

    # Sumário
    print("\n" + "=" * 60)
    print("📊 SUMÁRIO DOS TESTES")
    print("=" * 60)

    for test_name, result in results:
        status = "✅ PASSOU" if result else "❌ FALHOU"
        print(f"{status} - {test_name}")

    all_passed = all(result for _, result in results)

    print("\n" + "=" * 60)
    if all_passed:
        print("🎉 TODOS OS TESTES PASSARAM!")
        print("✅ O sistema está pronto para deploy")
        return 0
    else:
        print("⚠️  ALGUNS TESTES FALHARAM")
        print("❌ Revise os erros antes de fazer deploy")
        return 1

if __name__ == "__main__":
    sys.exit(main())
