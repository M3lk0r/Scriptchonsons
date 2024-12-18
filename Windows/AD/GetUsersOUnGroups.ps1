# Defina a OU de origem
$OU = "OU=Agripecas,DC=agripecas,DC=net"

# Caminho para exportar o arquivo CSV
$outputFile = "C:\export\usuarios_grupos.csv"

# Inicializa uma lista para armazenar as informações
$usersInfo = @()

Import-Module ActiveDirectory

# Obtém todos os usuários da OU especificada
$users = Get-ADUser -Filter * -SearchBase $OU -Properties DisplayName

# Itera por cada usuário
foreach ($user in $users) {
    # Obtém os grupos do usuário
    $groups = (Get-ADUser $user.SamAccountName -Properties MemberOf).MemberOf | 
        ForEach-Object { (Get-ADGroup $_).Name }

    # Cria um objeto com as informações desejadas
    $userInfo = [PSCustomObject]@{
        OU          = $OU
        Usuario     = $user.SamAccountName
        DisplayName = $user.DisplayName
        Grupos      = $groups -join ";"
    }

    # Adiciona o objeto à lista
    $usersInfo += $userInfo
}

# Exporta a lista de informações para um arquivo CSV
$usersInfo | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8

Write-Host "Exportação concluída para: $outputFile"
