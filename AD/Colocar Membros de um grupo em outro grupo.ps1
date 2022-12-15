Import-Module ActiveDirectory
$groupin = 'GGD_ColaboradoresDaimo1'
$groupout = 'GGD_ColaboradoresDaimo'
$usergroup1 = Get-ADGroupMember -Identity $groupout | Select-Object distinguishedName

foreach ($user in $usergroup1){
    Add-ADGroupMember -Identity $groupin -Members $user.distinguishedName -WhatIf
}