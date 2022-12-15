$sourceNewVersionRelease = 'C:\Azure_Deploy_Release\esAccessCenterNew\bin\Release\*'
$sourceNewVersionRel = 'C:\Azure_Deploy_Release\Relatorios\*'
$services = Get-Service -Name ERP*
$dirServices = Get-ChildItem -Path 'C:\ERP Client\Servicos\'

Get-ScheduledTask -TaskPath "\ERP\*" | Disable-ScheduledTask
Get-ScheduledTask -TaskPath "\ERP\*" | Stop-ScheduledTask

foreach ($serv in $services){
    $statuserpserv = Get-Service -Name $serv

    switch ($statuserpserv) {
        "running" { Write-Host "bixinho"} 
        Default {Write-Host "não bixinho" }
    }

    switch (Get-Service -Name spool* | Select-Object status) {
        "running" { Write-Host "bixinho"} 
        Default {Write-Host "não bixinho" }
    }


    Stop-Service $serv
}
    Stop-Process -Name "esAccessCenterWindowsServiceHost" -Force
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


Get-ScheduledTask -TaskPath "\ERP\*" | Enable-ScheduledTask