# Nome do script: UpdateADUserInfo.ps1
Import-Module ActiveDirectory

# Definições de variáveis
$csvPath = "\\ad02\User_logs\updategeral.csv"
$delimiter = ";"
$encoding = "Default"
$domainSuffix = "@complem.com.br"
$webPage = "https://complem.com.br"

# Importa os dados do CSV
$arquivo = Import-Csv -Path $csvPath -Delimiter $delimiter -Encoding $encoding

# Função para atualizar informações dos usuários no Active Directory
function Update-ADUserInfo {
    param (
        [array]$users
    )

    foreach ($user in $users) {
        try {
            # Obtém o usuário do Active Directory
            $adUser = Get-ADUser -Identity $user.Usuario -Properties *

            # Atualiza as informações do usuário
            Set-ADUser -Identity $user.Usuario `
                -Office $user.Office `
                -Surname $user.LastName `
                -Company $user.Company `
                -StreetAddress $user.StreetAddress `
                -Description $user.Title `
                -Department $user.Department `
                -Title $user.Title `
                -City $user.City `
                -State $user.State `
                -Country "BR" `
                -PostalCode $user.PostalCode `
                -Replace @{'ipPhone'=$user.mat; 
                            'wWWHomePage'=$webPage; 
                            'mail'=($user.Usuario + $domainSuffix); 
                            'telephoneNumber'=$user.Telefone}
            
            Write-Host "Updated user: $($user.Usuario)"

        } catch {
            Write-Warning "Failed to update user: $($user.Usuario) - $_"
        }
    }
}

# Executa a função de atualização
Update-ADUserInfo -users $arquivo