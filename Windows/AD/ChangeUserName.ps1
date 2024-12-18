Import-Module ActiveDirectory

$csv = "\\ad02\User_logs\updategeralname.csv"
$arquivo = Import-Csv -Path $csv -Encoding Default -Delimiter ";"


Function ChangeUserCN {
    foreach ($user in $arquivo) {
        Rename-ADObject -Identity $user.dname -NewName $user.NAME
    }
}


Function ChangeUserFirstName {
    foreach ($user in $arquivo) {
        $aduser = Get-ADUser -Identity $user.Usuario -Properties *
        Set-ADUser -Identity $user.Usuario -GivenName $user.FirstName -Surname $user.LastName
    }
}

ChangeUserCN
ChangeUserFirstName