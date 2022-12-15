$userpath = Get-ChildItem -Path 'C:\Users\'

foreach ($user in $userpath) {
    $path = $user.FullName
    Remove-Item -Path $path\AppData\Roaming\TeamViewer -Force -Verbose
    Remove-Item -Path $path\AppData\Local\TeamViewer -Force -Verbose
    Remove-Item -Path $path\AppData\Local\Temp\TeamViewer -Force -Verbose
    Remove-Item -Path $path\AppData\Roaming\TeamViewer -Force -Verbose
    Remove-Item -Path 'C:\Program Files (x86)\TeamViewer' -Force -Verbose
    Remove-Item -Path 'C:\Program Files\TeamViewer' -Force -Verbose
}



$userpath = Get-ChildItem -Path 'C:\Users\'
foreach ($user in $userpath) {
    $path = $user.FullName
    Get-Item -Path $path\AppData\Roaming\TeamViewer
    Get-Item -Path 'C:\Program Files (x86)\TeamViewer'
    Get-Item -Path 'C:\Program Files\TeamViewer'
}