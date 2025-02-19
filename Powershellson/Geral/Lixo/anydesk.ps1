# Função para verificar se o AnyDesk está instalado
function Is-AnydeskInstalled {
    $anydeskPath = "C:\Program Files (x86)\AnyDesk\AnyDesk.exe"
    return Test-Path $anydeskPath
}

# Função para desinstalar o AnyDesk
function Uninstall-Anydesk {
    Write-Output "Removendo versão existente do AnyDesk..."
    Start-Process "C:\Program Files (x86)\AnyDesk\AnyDesk.exe" -ArgumentList "--remove" -Wait
    Start-Sleep -Seconds 10
    Write-Output "AnyDesk removido."
}

# Verificar se o AnyDesk está instalado
if (Is-AnydeskInstalled) {
    Uninstall-Anydesk
}

# Baixar o instalador do AnyDesk
$installerUrl = "https://download.anydesk.com/AnyDesk.exe"
$installerPath = "$env:temp\AnyDesk.exe"
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath

# Instalar AnyDesk silenciosamente
Write-Output "Instalando AnyDesk..."
Start-Process -FilePath $installerPath -ArgumentList "/install /silent" -Wait

# Esperar alguns segundos para a instalação ser concluída
Start-Sleep -Seconds 10

# Configurar a senha de acesso remoto
$serviceConfPath = "$env:ProgramData\AnyDesk\service.conf"
if (-Not (Test-Path $serviceConfPath)) {
    New-Item -ItemType File -Path $serviceConfPath -Force
}
Add-Content -Path $serviceConfPath -Value "ad.security.password_hash=MtbiWmTk!#%"
Add-Content -Path $serviceConfPath -Value "ad.security.allow_logon=1"

# Reiniciar o serviço AnyDesk para aplicar as mudanças
Restart-Service -Name AnyDesk

# Remover o instalador
Remove-Item -Path $installerPath -Force

Write-Output "AnyDesk instalado e configurado com sucesso."
