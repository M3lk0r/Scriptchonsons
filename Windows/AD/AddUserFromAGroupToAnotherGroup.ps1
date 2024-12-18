# Nome do script: AddGroupMembers.ps1
Import-Module ActiveDirectory

# Definições de variáveis
$sourceGroup = 'GGD_ColaboradoresDaimo'
$targetGroup = 'GGD_ColaboradoresDaimo1'

# Função para adicionar membros de um grupo a outro
function Add-MembersToGroup {
    param (
        [string]$sourceGroup,
        [string]$targetGroup
    )

    # Obtém os membros do grupo de origem
    try {
        $userGroupMembers = Get-ADGroupMember -Identity $sourceGroup | Select-Object -ExpandProperty distinguishedName
    } catch {
        Write-Error "Falha ao obter membros do grupo '$sourceGroup': $_"
        return
    }

    # Adiciona cada membro ao grupo de destino
    foreach ($user in $userGroupMembers) {
        try {
            Add-ADGroupMember -Identity $targetGroup -Members $user
            Write-Host "Usuário $user adicionado ao grupo $targetGroup."
        } catch {
            Write-Warning "Falha ao adicionar o usuário $user ao grupo '$targetGroup': $_"
        }
    }
}

# Executa a função
Add-MembersToGroup -sourceGroup $sourceGroup -targetGroup $targetGroup