# Nome do script: AddUsersToExchangeSignatureGroup.ps1
Import-Module ActiveDirectory

# Definindo variáveis
$searchBase = 'OU=COMPLEM,DC=complem,DC=br'
$groupName = 'GGS_AZ_Exchange_AplyRule_Signature'

# Função para adicionar usuários a um grupo do Active Directory
function Add-UsersToGroup {
    param (
        [string]$searchBase,
        [string]$groupName
    )

    # Obtém todos os usuários da unidade organizacional especificada
    $users = Get-ADUser -SearchBase $searchBase -Filter *

    # Adiciona cada usuário ao grupo especificado
    foreach ($user in $users) {
        try {
            Add-ADGroupMember -Identity $groupName -Members $user -ErrorAction Stop
            Write-Host "Usuário $($user.SamAccountName) adicionado ao grupo $groupName."
        } catch {
            Write-Warning "Falha ao adicionar o usuário $($user.SamAccountName) ao grupo '$groupName': $_"
        }
    }
}

# Executa a função
Add-UsersToGroup -searchBase $searchBase -groupName $groupName