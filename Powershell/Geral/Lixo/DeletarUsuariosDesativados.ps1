# Obter todos os usuários locais no sistema
$users = Get-LocalUser

# Verificar cada usuário
foreach ($user in $users) {
    # Se o usuário estiver desativado
    if ($user.Enabled -eq $false) {
        Write-Host "Deletando usuário desativado: $($user.Name)"
        Remove-LocalUser -Name $user.Name
    } else {
        Write-Host "Usuário ativo: $($user.Name) - Não será deletado"
    }
}

Write-Host "Todos os usuários desativados foram deletados."
