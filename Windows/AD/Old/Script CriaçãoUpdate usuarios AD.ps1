Import-Module ActiveDirectory

$csv = "\\ad02\User_logs\user_gtba.csv"
$arquivo = Import-Csv -Path $csv -Delimiter ";" -Encoding Default

function create {
    foreach ($user in $arquivo) {
        New-ADUser -GivenName $user.FirstName `
        -Surname $user.LastName `
        -SamAccountName $user.Usuario `
        -DisplayName $user.NAME `
        -Name $user.NAME `
        -Description $user.Title `
        -Department $user.Department `
        -Title $user.Title `
        -UserPrincipalName ($user.Usuario+"@complem.com.br") `
        -Path $user.ou `
        -AccountPassword (ConvertTo-SecureString "complem123" -AsPlainText -Force) -Enabled $true -ChangePasswordAtLogon $true
    }
}

function update {
    foreach ($user in $arquivo) {
        $ud = Get-ADUser -Identity $user.Usuario -Properties *

        Set-ADUser -Identity $user.Usuario -Office $user.Office -Company $user.Office -StreetAddress $user.StreetAddress `
        -City $user.City -State $user.State -Country "BR" -PostalCode $user.PostalCode -Replace @{'ipPhone'=$user.mat;'wWWHomePage'="https://complem.com.br";'mail'=($user.Usuario+"@complem.com.br");'telephoneNumber'=$user.phone}   
    }
}

create
update