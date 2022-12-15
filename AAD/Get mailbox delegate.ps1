Install-Module -Name AzureAD
Install-Module -Name ExchangeOnlineManagement

$TenantId = ""
 
Import-module ExchangeOnlineManagement
Connect-ExchangeOnline -Organization $TenantId
 
$mailboxes = Get-Mailbox
$array=@()
foreach ($mailbox in $mailboxes) {

    $perm = Get-MailboxPermission $mailbox.Alias | Select-Object Identity, User, AccessRights 
    $array += $perm
}

$array | Export-Csv C:\temp\teste1.csv
