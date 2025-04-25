<#
.SYNOPSIS
   Hardening básico e avançado para Windows Server 2025 membro de domínio.
.DESCRIPTION
   Aplica configurações de segurança, políticas de senha, desabilita protocolos e serviços inseguros,
   habilita auditoria, BitLocker, Defender, atualizações automáticas, horário sincronizado no DC etc.
.NOTES
   Testar em LAB antes de rodar em produção.
#>

#region PARÂMETROS E VARIÁVEIS DE AMBIENTE
param(
    [string]$DomainName     = 'contoso.local',
    [string]$NtpServer       = 'dc01.contoso.local',
    [string]$BitLockerVolume = 'C:',
    [string]$PublicKeyPath   = 'C:\Keys\TPM_PubKey.pem'  # se usar escudo de chave
)
# Listas de serviços a desabilitar
$ServicesToDisable = @(
    'Spooler',               # Impressão se não for servidor de impressão
    'RemoteRegistry',        # Desabilita edição remota de registro
    'XblGameSave',           # Gaming services
    'XboxNetApiSvc',
    'MapsBroker',
    'PhoneSvc',
    'RetailDemo',
    'WSearch'                # Windows Search se não necessário
)
# Protocolos inseguros
$DisableProtocols = @(
  @{Key='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name='LmCompatibilityLevel'; Value=5},  # Somente NTLMv2
  @{Key='HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'; Name='SMB1'; Value=0},  # Desab. SMBv1
  @{Key='HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb10'; Name='Start'; Value=4},              # Desab SMB1 driver
  @{Key='HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb20'; Name='Start'; Value=3}               # Garante SMB2 ativado
)
#endregion

Function Assert-Admin {
    If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "É necessário rodar como Administrador!"
        Exit 1
    }
}

Function Set-WindowsUpdate {
    Write-Host "Configurando Windows Update para Instalar Automaticamente…" -ForegroundColor Cyan
    # 4 = Auto download e schedule install
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 4 -Type DWord -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord -Force | Out-Null
}

Function Set-TimeSync {
    Write-Host "Configurando sincronização de hora com $NtpServer…" -ForegroundColor Cyan
    w32tm /config /update /manualpeerlist:$NtpServer /syncfromflags:manual | Out-Null
    w32tm /config /reliable:no | Out-Null
    Restart-Service w32time
    w32tm /resync | Out-Null
}

Function Set-PasswordPolicyLocal {
    Write-Host "Ajustando política local de senha e bloqueio de conta…" -ForegroundColor Cyan
    & secedit /export /cfg C:\Windows\Temp\secbaseline.inf
    (Get-Content C:\Windows\Temp\secbaseline.inf) -replace '^PasswordComplexity = .*','PasswordComplexity = 1' |
      Set-Content C:\Windows\Temp\secbaseline.inf
    (Get-Content C:\Windows\Temp\secbaseline.inf) -replace '^MinimumPasswordLength = .*','MinimumPasswordLength = 14' |
      Set-Content C:\Windows\Temp\secbaseline.inf
    (Get-Content C:\Windows\Temp\secbaseline.inf) -replace '^LockoutBadCount = .*','LockoutBadCount = 5' |
      Set-Content C:\Windows\Temp\secbaseline.inf
    (Get-Content C:\Windows\Temp\secbaseline.inf) -replace '^ResetLockoutCount = .*','ResetLockoutCount = 15' |
      Set-Content C:\Windows\Temp\secbaseline.inf
    secedit /configure /db seclocal.sdb /cfg C:\Windows\Temp\secbaseline.inf /areas SECURITYPOLICY | Out-Null
    Remove-Item C:\Windows\Temp\secbaseline.inf -Force
}

Function Disable-WeakProtocols {
    Write-Host "Desabilitando protocolos e modos inseguros…" -ForegroundColor Cyan
    foreach ($p in $DisableProtocols) {
        New-Item -Path $p.Key -Force | Out-Null
        New-ItemProperty -Path $p.Key -Name $p.Name -Value $p.Value -PropertyType DWord -Force | Out-Null
    }
}

Function Disable-Services {
    Write-Host "Desabilitando serviços desnecessários…" -ForegroundColor Cyan
    foreach ($svc in $ServicesToDisable) {
        If (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled
        }
    }
}

Function Edit-Registry {
    Write-Host "Aplicando ajustes finos no registro…" -ForegroundColor Cyan
    $regs = @(
        # Desabilita LLMNR
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient';Name='EnableMulticast';Value=0},
        # Desabilita NetBIOS over Tcp
        @{Path='HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters';Name='TransportBindName';Value=0x00000000},
        # RDP – NLA obrigatório
        @{Path='HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp';Name='UserAuthentication';Value=1},
        # Exigir criptografia no RDP
        @{Path='HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp';Name='MinEncryptionLevel';Value=3}
    )
    foreach ($r in $regs) {
        New-Item -Path $r.Path -Force | Out-Null
        New-ItemProperty -Path $r.Path -Name $r.Name -Value $r.Value -PropertyType DWord -Force | Out-Null
    }
}

Function Enable-AuditPolicy {
    Write-Host "Configurando auditoria avançada (Success & Failure)…" -ForegroundColor Cyan
    $categories = @(
        'Account Logon',
        'Account Management',
        'Logon/Logoff',
        'Policy Change',
        'Privilege Use',
        'System'
    )
    foreach ($cat in $categories) {
        auditpol /set /category:$cat /success:enable /failure:enable | Out-Null
    }
}

Function Enable-SecurityFeatures {
    Write-Host "Habilitando Windows Defender, Tamper Protection e Credential Guard…" -ForegroundColor Cyan
    # Defender em tempo real
    Set-MpPreference -DisableRealtimeMonitoring $false
    # Tamper Protection (via registry; GPOs no domínio podem prevalecer)
    New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features' -Name 'TamperProtection' -PropertyType DWord -Value 5 -Force | Out-Null

    # Credential Guard (Host Guardian)—se a máquina for compatível
    bcdedit /set hypervisorlaunchtype auto | Out-Null
    bcdedit /set vmichypervisor present | Out-Null
}

Function Enable-BitLocker {
    Write-Host "Habilitando BitLocker no volume $BitLockerVolume…" -ForegroundColor Cyan
    # Assumindo que TPM está presente e ativo
    Enable-BitLocker -MountPoint $BitLockerVolume -TpmProtector -UsedSpaceOnly -EncryptionMethod Aes256 -Confirm:$false
    # Se quiser adicionar chave externa:
    # Add-BitLockerKeyProtector -MountPoint $BitLockerVolume -ExternalKey $PublicKeyPath
}

# --------------------------------------------------
# Execução
# --------------------------------------------------
Assert-Admin
Set-WindowsUpdate
Set-TimeSync
Set-PasswordPolicyLocal
Disable-WeakProtocols
Disable-Services
Edit-Registry
Enable-AuditPolicy
Enable-SecurityFeatures
#Enable-BitLocker

Write-Host "`n*** Baseline de hardening aplicado. Recomenda-se reiniciar o servidor. ***" -ForegroundColor Green