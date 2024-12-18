# Variáveis
$OU = "OU=Agripecas,DC=agripecas,DC=net" # Substitua pelo caminho da sua OU
$GroupNameToAdd = "Agripecas Users" # Substitua pelo nome do grupo a ser adicionado
$GroupNameToRemove = "Domain Users" # Substitua pelo nome do grupo a ser removido

# Função 1: Adicionar um grupo a todos os usuários de uma determinada OU
function Add-GroupToUsersInOU {
    $users = Get-ADUser -Filter * -SearchBase $OU
    foreach ($user in $users) {
        Add-ADGroupMember -Identity $GroupNameToAdd -Members $user.SamAccountName
        Write-Host "User $($user.SamAccountName) added to group $GroupNameToAdd"
    }
}

# Função 2: Verificar se os usuários de uma determinada OU estão em um determinado grupo e, se sim, definir como grupo principalfunction Set-PrimaryGroupForUsersInOU {
function Set-PrimaryGroupForUsersInOU {
    # Tentar obter o grupo NewPrimaryGroup
    try {
        $group = Get-ADGroup -Identity $GroupNameToAdd -Properties PrimaryGroupToken
        Write-Host "Group NewPrimaryGroup found: $($group.DistinguishedName)"
    }
    catch {
        Write-Host "Error retrieving group NewPrimaryGroup: $_"
        return
    }
    
    # Obter o PrimaryGroupID do grupo
    $primaryGroupID = [string]$group.PrimaryGroupToken
    if ($primaryGroupID -eq $null -or $primaryGroupID -eq 0) {
        Write-Host "Invalid PrimaryGroupID for NewPrimaryGroup."
        return
    }
    
    # Obter todos os usuários na OU especificada
    $users = Get-ADUser  -Filter * -SearchBase $OU
    foreach ($user in $users) {
        # Verificar se o usuário é membro do grupo Agripecas Users
        $groupMemberships = Get-ADUser  -Identity $user.SamAccountName -Property MemberOf | Select-Object -ExpandProperty MemberOf
    
        if ($groupMemberships -contains (Get-ADGroup -Identity $GroupNameToAdd).DistinguishedName) {
            # Definir o grupo como o grupo principal
            try {
                Set-ADUser  -Identity $user.SamAccountName -Replace @{primaryGroupID = $primaryGroupID }
                Write-Host "Primary group set to NewPrimaryGroup for user $($user.SamAccountName)"
            }
            catch {
                Write-Host "Failed to set primary group for user $($user.SamAccountName): $_"
            }
        }
        else {
            Write-Host "User  $($user.SamAccountName) is not a member of $GroupNameToAdd, cannot set as primary group."
        }
    }
}

# Função 3: Verificar se o usuário tem um determinado grupo e se ele é o grupo principal; caso contrário, remover o grupo
function Remove-Group {
    # Tentar obter o grupo a ser removido
    try {
        $groupToRemove = Get-ADGroup -Identity $GroupNameToRemove -Properties DistinguishedName
        Write-Host "Group $GroupNameToRemove found: $($groupToRemove.DistinguishedName)"
    }
    catch {
        Write-Host "Error retrieving group ${GroupNameToRemove}: $_"
        return
    }

    # Obter todos os usuários na OU especificada
    $users = Get-ADUser -Filter * -SearchBase $OU
    foreach ($user in $users) {
        # Obter as associações de grupo do usuário
        $groupMemberships = Get-ADUser -Identity $user.SamAccountName -Property MemberOf | Select-Object -ExpandProperty MemberOf

        # Verificar se o usuário é membro do grupo a ser removido
        if ($groupMemberships -contains $groupToRemove.DistinguishedName) {
            try {
                Remove-ADGroupMember -Identity $GroupNameToRemove -Members $user.SamAccountName -Confirm:$false
                Write-Host "Removed $GroupNameToRemove from user $($user.SamAccountName)"
            }
            catch {
                Write-Host "Failed to remove $GroupNameToRemove from user $($user.SamAccountName): $_"
            }
        }
    }
}

# Chamada das funções
#Add-GroupToUsersInOU
#Set-PrimaryGroupForUsersInOU
#Remove-Group


