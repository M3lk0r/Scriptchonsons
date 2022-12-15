$OU = 'OU=DAIMO,OU=FILIAIS,DC=complem,DC=br'
$Group = 'Colaboradores DAIMO'
Get-ADUser -SearchBase $OU -Filter * | % { Add-ADGroupMember $Group -Members $_ -WhatIf }