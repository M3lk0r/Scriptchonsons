Import-Module ActiveDirectory

$csv = "C:\Users\adm.gomes\Desktop\passwordnerver.csv"
$arquivo = Import-Csv -Path $csv -Delimiter ";" -Encoding Default

function update {
    foreach ($user in $arquivo) {
        $ud = Get-ADUser -Identity $user.Username -Properties *

       Set-ADUser -Identity $user.Username -PasswordNeverExpires $false
    }
}

update