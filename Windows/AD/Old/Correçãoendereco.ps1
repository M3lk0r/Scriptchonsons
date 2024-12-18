Import-Module ActiveDirectory

$csv = "\\ad02\User_logs\updategeral.csv"
$arquivo = Import-Csv -Path $csv -Delimiter ";" -Encoding Default


function update {
    foreach ($user in $arquivo) {
        $ud = Get-ADUser -Identity $user.Usuario -Properties *

        Set-ADUser -Identity $user.Usuario -Office $user.Office -Surname $user.LastName -Company $user.Company -StreetAddress $user.StreetAddress -Description $user.Title -Department $user.Department -Title $user.Title`
        -City $user.City -State $user.State -Country "BR" -PostalCode $user.PostalCode -Replace @{'ipPhone'=$user.mat;'wWWHomePage'="https://complem.com.br";'mail'=($user.Usuario+"@complem.com.br");'telephoneNumber'=$user.Telefone}   
    }
}

update