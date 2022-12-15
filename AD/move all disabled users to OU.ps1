$moveToOU = "CN=OU Name,DC=doman,DC=com"

Search-ADAccount -AccountDisabled -UsersOnly |
Select-Object Name,Distinguishedname |
Out-GridView -OutputMode Multiple |
foreach { 
    Move-ADObject -Identity $_.DistinguishedName -TargetPath $moveToOU -WhatIf
}