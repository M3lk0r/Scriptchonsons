# Nome do script: MoveDisabledUsersToOU.ps1

# Definindo a OU de destino para onde os usuários desativados serão movidos
$moveToOU = "OU=OU Name,DC=domain,DC=com"

# Função para mover contas de usuários desativadas para a unidade organizacional especificada
function Move-DisabledUsersToOU {
    param (
        [string]$targetOU
    )

    # Obtém contas de usuários desativadas
    $disabledUsers = Search-ADAccount -AccountDisabled -UsersOnly | Select-Object Name, DistinguishedName

    # Verifica se há usuários desativados encontrados
    if ($disabledUsers.Count -eq 0) {
        Write-Host "Nenhum usuário desativado encontrado."
        return
    }

    # Apresenta a lista de usuários desativados para seleção
    $selectedUsers = $disabledUsers | Out-GridView -OutputMode Multiple

    # Move os usuários selecionados para a unidade organizacional
    foreach ($user in $selectedUsers) {
        try {
            Move-ADObject -Identity $user.DistinguishedName -TargetPath $targetOU -ErrorAction Stop -WhatIf
            Write-Host "Usuário '$($user.Name)' será movido para '$targetOU'."
        } catch {
            Write-Warning "Falha ao mover o usuário '$($user.Name)': $_"
        }
    }
}

# Executa a função
Move-DisabledUsersToOU -targetOU $moveToOU