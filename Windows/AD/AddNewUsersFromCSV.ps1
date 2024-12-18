# Importa o módulo ActiveDirectory
Import-Module ActiveDirectory

# Variáveis de configuração
$csvPath = "\\ad02\User_logs\updategeralbeta.csv"
$csvDelimiter = ";"
$csvEncoding = "UTF8"
$defaultPassword = "complem123"
$domainSuffix = "@complem.com.br"
$websiteURL = "https://complem.com.br"
$country = "BR"

# Importa os dados do CSV
$arquivo = Import-Csv -Path $csvPath -Delimiter $csvDelimiter -Encoding $csvEncoding

# Converte a senha padrão em um formato seguro
$password = ConvertTo-SecureString $defaultPassword -AsPlainText -Force

# Função para criar novos usuários
function Create-Users {
    foreach ($user in $arquivo) {
        try {
            # Verifica se o usuário já existe antes de criar
            if (-not (Get-ADUser -Filter {SamAccountName -eq $user.Usuario})) {
                New-ADUser -GivenName $user.FirstName `
                    -Surname $user.LastName `
                    -SamAccountName $user.Usuario `
                    -DisplayName $user.NAME `
                    -Name $user.NAME `
                    -Description $user.Title `
                    -Department $user.Department `
                    -Title $user.Title `
                    -UserPrincipalName ($user.Usuario + $domainSuffix) `
                    -Path $user.ou `
                    -AccountPassword $password -Enabled $true -ChangePasswordAtLogon $true

                Write-Host "User $($user.Usuario) created successfully."
            } else {
                Write-Host "User $($user.Usuario) already exists. Skipping creation."
            }
        } catch {
            Write-Warning "Error creating user $($user.Usuario): $_"
        }
    }
}

# Função para atualizar usuários existentes
function Update-Users {
    foreach ($user in $arquivo) {
        try {
            $ud = Get-ADUser -Identity $user.Usuario -Properties *
            
            if ($ud) {
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
                    -Country $country `
                    -PostalCode $user.PostalCode `
                    -Replace @{
                        'ipPhone' = $user.mat
                        'wWWHomePage' = $websiteURL
                        'mail' = ($user.Usuario + $domainSuffix)
                        'telephoneNumber' = $user.Telefone
                    }

                Write-Host "User $($user.Usuario) updated successfully."
            } else {
                Write-Warning "User $($user.Usuario) not found. Skipping update."
            }
        } catch {
            Write-Warning "Error updating user $($user.Usuario): $_"
        }
    }
}

Create-Users
Update-Users