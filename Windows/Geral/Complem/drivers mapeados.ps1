# This is required for Verbose to work correctly.
# If you don't want the Verbose message, remove "-Verbose" from the Parameters field.
[CmdletBinding()]
param ()
$Drives = Get-ItemProperty "Registry::HKEY_USERS\*\Network\*"
if ( $Drives ) {
    ForEach ( $Drive in $Drives ) {
        $SID = ($Drive.PSParentPath -split '\\')[2]
        [PSCustomObject]@{
            Username            = ([System.Security.Principal.SecurityIdentifier]"$SID").Translate([System.Security.Principal.NTAccount])
            DriveLetter         = $Drive.PSChildName
            RemotePath          = $Drive.RemotePath

            ConnectWithUsername = $Drive.UserName -replace '^0$', $null
            SID                 = $SID
        }
    }
} else {
    Write-Verbose "No mapped drives were found"
}