$pathNewVersionBin = 'C:\Azure_Deploy_Release\esAccessCenterService\bin'
$pathNewVersionRel = 'C:\Azure_Deploy_Release\Relatorios'
$service01 = 'ERP Dev - 1591'
$service02 = 'ERP Client - 1581'
$pathService01 = 'C:\ERP Client\Servicos\Homolog-Dev\'
$pathService02 = 'C:\ERP Client\Servicos\Homolog-Client\'

taskkill /IM esAccessCenter* /F
    try {
        Write-Host "O serviços foram parados e as aplicações encerradas."`n -ForegroundColor Yellow

        Copy-Item -Path $pathNewVersionBin -Destination $pathService01 -Recurse -Force
        Copy-Item -Path $pathNewVersionRel -Destination $pathService01 -Recurse -Force
        Copy-Item -Path $pathNewVersionBin -Destination $pathService02 -Recurse -Force
        Copy-Item -Path $pathNewVersionRel -Destination $pathService02 -Recurse -Force
        try{
            Write-Host "Nova versao foi inserida nas pastas dos servicos."`n -ForegroundColor Yellow

            Start-Service $service01
            Start-Service $service02
            Write-Host "O serviços foram iniciados!!!!!"`n -ForegroundColor Yellow
        } 
        Catch [System.Management.Automation.ActionPreferenceStopException] {
            Write-Host "Deu ruim:"`n -ForegroundColor Blue
            Write-Host "Message: [$($_.Exception.Message)"] -ForegroundColor Red -BackgroundColor DarkBlue
        }
    }        
    Catch [System.IO.FileNotFoundException] {
        Write-Host "Deu ruim:"`n -ForegroundColor Blue
        Write-Host "Message: [$($_.Exception.Message)"] -ForegroundColor Red -BackgroundColor DarkBlue
    }
