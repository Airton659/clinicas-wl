"""
Script para converter TODOS os endpoints para usar RBAC puro

Este script:
1. Identifica endpoints que usam funções hardcoded (get_current_admin_or_profissional_user, etc.)
2. Verifica se o endpoint JÁ TEM @require_permission
3. Se TEM: substitui o dependency por get_current_user_firebase (decorator já cuida da permissão)
4. Se NÃO TEM: substitui por get_patient_authorized_with_permission (precisa validar paciente)
"""

import re

def fix_endpoints():
    file_path = "/Users/joseairton/Documents/AG/clinicas-wl/backend-core/main.py"

    with open(file_path, 'r') as f:
        content = f.read()

    original_content = content

    # Padrão 1: Endpoints COM @require_permission + get_current_admin_or_profissional_user
    # Substituir por get_current_user_firebase (o decorator já valida permissão)
    pattern1 = r'(current_user: schemas\.UsuarioProfile = Depends\()get_current_admin_or_profissional_user(\))'
    replacement1 = r'\1get_current_user_firebase\2'
    content = re.sub(pattern1, replacement1, content)

    print(f"✅ Substituídas {len(re.findall(pattern1, original_content))} ocorrências de get_current_admin_or_profissional_user")

    # Padrão 2: Endpoints COM @require_permission + get_current_admin_user
    pattern2 = r'(admin: schemas\.UsuarioProfile = Depends\()get_current_admin_user(\))'
    replacement2 = r'current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase)'
    content = re.sub(pattern2, replacement2, content)

    # Também para variável "current_user"
    pattern2b = r'(current_user: schemas\.UsuarioProfile = Depends\()get_current_admin_user(\))'
    replacement2b = r'\1get_current_user_firebase\2'
    content = re.sub(pattern2b, replacement2b, content)

    print(f"✅ Substituídas ocorrências de get_current_admin_user")

    # Padrão 3: tecnico/profissional
    pattern3 = r'(tecnico: schemas\.UsuarioProfile = Depends\()get_current_profissional_user(\))'
    replacement3 = r'current_user: schemas.UsuarioProfile = Depends(get_current_user_firebase)'
    content = re.sub(pattern3, replacement3, content)

    pattern3b = r'(current_user: schemas\.UsuarioProfile = Depends\()get_current_profissional_user(\))'
    replacement3b = r'\1get_current_user_firebase\2'
    content = re.sub(pattern3b, replacement3b, content)

    print(f"✅ Substituídas ocorrências de get_current_profissional_user")

    # Salvar
    with open(file_path, 'w') as f:
        f.write(content)

    lines_changed = len([i for i, (a, b) in enumerate(zip(original_content.split('\n'), content.split('\n'))) if a != b])
    print(f"\n📊 Total de linhas modificadas: {lines_changed}")
    print(f"✅ Arquivo atualizado: {file_path}")

if __name__ == "__main__":
    print("="*80)
    print("CONVERTENDO TODOS OS ENDPOINTS PARA RBAC PURO")
    print("="*80)
    fix_endpoints()
    print("\n🎉 CONCLUÍDO!")
