$moveToOU = "CN=OU Name,DC=doman,DC=com"

Get-ADUser -filter {Enabled -eq $false } | Foreach-object {
  Move-ADObject -Identity $_.DistinguishedName -TargetPath $moveToOU -WhatIf
}