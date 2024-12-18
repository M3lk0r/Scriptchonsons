# Especifique as contas que você NÃO deseja desativar
$accountsToKeep = @("Administrator", "Guest")

# Obter todos os usuários locais no sistema
$users = Get-LocalUser

# Desativar todos os usuários, exceto os especificados em $accountsToKeep
foreach ($user in $users) {
    if ($accountsToKeep -notcontains $user.Name) {
        Write-Host "Desativando usuário: $($user.Name)"
        Disable-LocalUser -Name $user.Name
    } else {
        Write-Host "Mantendo usuário ativo: $($user.Name)"
    }
}

Write-Host "Todos os usuários locais, exceto os especificados, foram desativados."
