if (-not (Get-Module -Name ActiveDirectory)) {
    Import-Module ActiveDirectory
}

$csvPath = "C:\teste\users.csv"
$ouPath = "OU=Usuarios,OU=Edeia,OU=Agripecas,DC=agripecas,DC=net"

$usuarios = Import-Csv -Path $csvPath -Delimiter ";" -Encoding UTF8

function create {
    foreach ($usuario in $usuarios) {
        $nome = $usuario.Nome
        $sobrenome = $usuario.Sobrenome
        $username = $usuario.Username
        $senhaPadrao = "Mudar@123"
        $streetAddress = $usuario.StreetAddress
        $departamento = "Agripeças"

        if (-not [string]::IsNullOrWhiteSpace($senhaPadrao)) {
            $senhaSecure = ConvertTo-SecureString -String $senhaPadrao -AsPlainText -Force
            try {
                New-ADUser `
                    -Name "$nome $sobrenome" `
                    -DisplayName "$nome $sobrenome" `
                    -GivenName $nome `
                    -Surname $sobrenome `
                    -SamAccountName $username `
                    -UserPrincipalName "$username@agripecas.net" `
                    -AccountPassword $senhaSecure `
                    -StreetAddress $streetAddress `
                    -Department $departamento `
                    -ChangePasswordAtLogon $true `
                    -Enabled $true `
                    -Path $ouPath
            }
            catch {
                Write-Host "Erro ao criar usuário $($username): $_"
            }
        }
        else {
            Write-Host "A senha para o usuário $($username) está vazia ou não foi fornecida."
        }
    }
}

function update {
    foreach ($usuario in $usuarios) {
        $username = $usuario.Username
        $state = "GO"
        $company = $usuario.agripecas
        $office = $usuario.agripecas
        $sobrenome = $usuario.Sobrenome
        $streetaddress = $usuario.StreetAddress
        $zip = $usuario.Zip
        $email = $usuario.Email
        $city = $usuario.City
        $jobTitle = "Funcionario"
        $telefone = $usuario.Telefone
        $departamento = $usuario.Departamento
        $title = "Funcionario"
        $webPage = "https://solution.grupoagripecas.com/servlet/erpsolution.ambiente.secloginerpsolution"

        $ud = Get-ADUser -Identity $username -Properties *
        try {
            Set-ADUser `
                -Identity $username `
                -Surname $sobrenome `
                -Company $company `
                -Office $office `
                -StreetAddress $streetaddress `
                -Description $title `
                -Department $departamento `
                -Title $jobTitle `
                -City $city `
                -State $state `
                -Country "BR" `
                -PostalCode $zip `
                -Replace @{'wWWHomePage' = $webPage; 'mail' = $email; 'telephoneNumber' = $telefone }   
        }
        catch {
            Write-Host "Erro ao dar update no usuário $($username): $_"
        }
    }
}

update