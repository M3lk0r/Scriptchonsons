Install-Module -Name AzureAD
Install-Module -Name ExchangeOnlineManagement

$TenantId = "b0f28ff1-7551-4fdc-9f70-24d15480919a"
 
Import-module ExchangeOnlineManagement
Connect-ExchangeOnline -Organization $TenantId
 
$mailboxes = Get-Mailbox
$array=@()
foreach ($mailbox in $mailboxes) {

    $perm = Get-MailboxPermission $mailbox.Alias | Select-Object Identity, User, AccessRights 
    $array += $perm
}

$array | Export-Csv C:\temp\teste1.csv