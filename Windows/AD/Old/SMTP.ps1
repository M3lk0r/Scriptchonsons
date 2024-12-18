Import-Module ActiveDirectory

$csv = "\\ad02\c$\Users\adm.gomes\Desktop\smtp01.csv"
$arquivo = Import-Csv -Path $csv -Delimiter ";" -Encoding Default 

#define domain here
$domain="@complem.com.br"


#adding proxies
$SMTP1="SMTP:"
$Smtp2="smtp:"


#adding all
$SMTP1=$SMTP1 + $arquivo.smtp + $domain
$SMTP2=$SMTP2 + $arquivo.smtp1 + $domain





foreach ($user in $arquivo) {
    Get-ADUser $user.user | set-aduser -Add @{Proxyaddresses=$user.smtp}
}