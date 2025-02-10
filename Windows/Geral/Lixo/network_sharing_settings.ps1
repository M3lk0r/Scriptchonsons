# Executar o script com permissões elevadas
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}

# Função para modificar o registro
function Set-RegistryValue {
    param (
        [string]$key,
        [string]$name,
        [string]$value,
        [Microsoft.Win32.RegistryValueKind]$type = [Microsoft.Win32.RegistryValueKind]::DWord
    )
    Set-ItemProperty -Path $key -Name $name -Value $value -Type $type
}

# Redes Privadas
Write-Host "Configurando redes privadas..."
# Desativa a descoberta de rede
Set-RegistryValue -key "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\HomeGroup" -name "NetworkDiscovery" -value 0
# Ativa o compartilhamento de arquivos e impressoras
Set-RegistryValue -key "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -name "AutoShareServer" -value 1

# Redes Públicas
Write-Host "Configurando redes públicas..."
# Desativa a descoberta de rede
Set-RegistryValue -key "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\HomeGroup" -name "NetworkDiscovery" -value 0
# Desativa o compartilhamento de arquivos e impressoras
Set-RegistryValue -key "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -name "AutoShareServer" -value 0

# Redes do Domínio
Write-Host "Configurando redes do domínio..."
# Desativa a descoberta de rede
Set-RegistryValue -key "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\HomeGroup" -name "NetworkDiscovery" -value 0
# Ativa o compartilhamento de arquivos e impressoras
Set-RegistryValue -key "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -name "AutoShareServer" -value 1

Write-Host "Configurações de compartilhamento avançadas foram aplicadas com sucesso."
pause
