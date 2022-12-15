Install-Module -Name AzureAD
Install-Module -Name ExchangeOnlineManagement

$AppId = "7ee81372-f445-4aed-86c2-20b0ea2fba09"
$TenantId = "b0f28ff1-7551-4fdc-9f70-24d15480919a"
 
Import-module AzureAD
Connect-AzureAd -Tenant $TenantId
 
($Principal = Get-AzureADServicePrincipal -filter "AppId eq '$AppId'")
$PrincipalId = $Principal.ObjectId

$DisplayName = "Principal for SMTP"
 
Import-module ExchangeOnlineManagement
Connect-ExchangeOnline -Organization $TenantId
 
New-ServicePrincipal -AppId $AppId -ServiceId $PrincipalId -DisplayName $DisplayName

Add-MailboxPermission -User $PrincipalId -AccessRights FullAccess -Identity "informe@complem.com.br"