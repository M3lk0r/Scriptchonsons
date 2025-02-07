$sourceNewVersionRelease = 'C:\Azure_Deploy_Release\esAccessCenterNew\bin\Release\*'
$sourceNewVersionRel = 'C:\Azure_Deploy_Release\Relatorios\*'
$services = Get-Service -Name ERP*
$dirServices = Get-ChildItem -Path 'C:\ERP Client\Servicos\'

try {
    foreach ($serv in $services){
        Stop-Service $serv
    }
    Stop-Process -Name "esAccessCenterWindowsServiceHost" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
} catch [System.Management.Automation.ActionPreferenceStopException] {
    foreach ($serv in $services){
        Start-Service $serv
    }
    Write-Host "Message: [$($_.Exception.Message)"] -ForegroundColor Red -BackgroundColor DarkBlue
    foreach ($serv in $services){
        Stop-Service $serv
    }
    Stop-Process -Name "esAccessCenterWindowsServiceHost" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
}

Write-Host "O serviços foram parados e as aplicações encerradas."`n -ForegroundColor Yellow

Start-Sleep -Seconds 5

try {Write-Host "O serviços foram parados e as aplicações encerradas."`n -ForegroundColor Yellow

    foreach ($dir in $dirServices){
        Copy-Item $sourceNewVersionRelease -Destination $dir.FullName -Recurse -Force
    }
    foreach ($dir in $dirServices){
        $asd = $dir.FullName
        Copy-Item $sourceNewVersionRel -Destination $asd"\Relatorios" -Recurse -Force
    }

    try{Write-Host "Nova versao foi inserida nas pastas dos servicos."`n -ForegroundColor Yellow

        foreach ($serv in $services){
            Start-Service $serv
        }
        Write-Host "O serviços foram iniciados!!!!!"`n -ForegroundColor Yellow
    } Catch [System.Management.Automation.ActionPreferenceStopException] {
        Write-Host "Deu ruim:"`n -ForegroundColor Blue
        Write-Host "Message: [$($_.Exception.Message)"] -ForegroundColor Red -BackgroundColor DarkBlue
    }
} Catch [System.IO.FileNotFoundException] {
    Write-Host "Deu ruim:"`n -ForegroundColor Blue
    Write-Host "Message: [$($_.Exception.Message)"] -ForegroundColor Red -BackgroundColor DarkBlue
}
