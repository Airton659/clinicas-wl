"""
Script para substituir get_paciente_autorizado e get_admin_or_profissional_autorizado_paciente
por get_patient_authorized_with_permission com a permissão correta
"""

import re

def extract_permission_from_decorator(lines, start_idx):
    """Extrai a permissão do decorator @require_permission acima do endpoint"""
    # Procurar para trás até encontrar @require_permission
    for i in range(start_idx, max(0, start_idx - 10), -1):
        match = re.search(r'@require_permission\("([^"]+)"\)', lines[i])
        if match:
            return match.group(1)
    return None

def fix_patient_endpoints():
    file_path = "/Users/joseairton/Documents/AG/clinicas-wl/backend-core/main.py"

    with open(file_path, 'r') as f:
        lines = f.readlines()

    modifications = 0

    # Processar linha por linha
    for i, line in enumerate(lines):
        # Padrão 1: get_paciente_autorizado com @require_permission acima
        if 'Depends(get_paciente_autorizado)' in line and '@require_permission' not in line:
            # Buscar permissão acima
            permission = extract_permission_from_decorator(lines, i)
            if permission:
                # Substituir
                lines[i] = line.replace(
                    'Depends(get_paciente_autorizado)',
                    f'Depends(get_patient_authorized_with_permission("{permission}"))'
                )
                modifications += 1
                print(f"✅ Linha {i+1}: get_paciente_autorizado → get_patient_authorized_with_permission(\"{permission}\")")

        # Padrão 2: get_admin_or_profissional_autorizado_paciente com @require_permission acima
        if 'Depends(get_admin_or_profissional_autorizado_paciente)' in line:
            permission = extract_permission_from_decorator(lines, i)
            if permission:
                lines[i] = line.replace(
                    'Depends(get_admin_or_profissional_autorizado_paciente)',
                    f'Depends(get_patient_authorized_with_permission("{permission}"))'
                )
                modifications += 1
                print(f"✅ Linha {i+1}: get_admin_or_profissional_autorizado_paciente → get_patient_authorized_with_permission(\"{permission}\")")

    # Salvar
    with open(file_path, 'w') as f:
        f.writelines(lines)

    print(f"\n📊 Total de modificações: {modifications}")
    print(f"✅ Arquivo atualizado: {file_path}")

if __name__ == "__main__":
    print("="*80)
    print("SUBSTITUINDO ENDPOINTS DE PACIENTES PARA RBAC")
    print("="*80)
    fix_patient_endpoints()
    print("\n🎉 CONCLUÍDO!")
