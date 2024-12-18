# Nome do script: MoveDisabledUsersToOU.ps1

# Definindo a OU de destino para onde os usuários desativados serão movidos
$moveToOU = "OU=OU Name,DC=domain,DC=com"

# Função para mover contas de usuários desativadas para a unidade organizacional especificada
function Move-DisabledUsersToOU {
    param (
        [string]$targetOU
    )

    # Obtém todos os usuários desativados
    $disabledUsers = Get-ADUser -Filter { Enabled -eq $false } -Properties DistinguishedName

    # Verifica se há usuários desativados encontrados
    if ($disabledUsers.Count -eq 0) {
        Write-Host "Nenhum usuário desativado encontrado."
        return
    }

    # Move cada usuário desativado para a unidade organizacional
    foreach ($user in $disabledUsers) {
        try {
            Move-ADObject -Identity $user.DistinguishedName -TargetPath $targetOU -ErrorAction Stop -WhatIf
            Write-Host "Usuário '$($user.SamAccountName)' será movido para '$targetOU'."
        } catch {
            Write-Warning "Falha ao mover o usuário '$($user.SamAccountName)': $_"
        }
    }
}

# Executa a função
Move-DisabledUsersToOU -targetOU $moveToOU