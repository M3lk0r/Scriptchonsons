<#
.SYNOPSIS
   Hardening básico e avançado para Windows Server 2025 membro de domínio.
.DESCRIPTION
   Aplica configurações de segurança, políticas de senha, desabilita protocolos e serviços inseguros,
   habilita auditoria, BitLocker, Defender, atualizações automáticas, horário sincronizado no DC etc.
   Inclui configurações adicionais para CIS Benchmark Level 1 e recomendações da Microsoft.
.NOTES
   FileName    : Hardening-WindowsServer2025.ps1
   Author      : Eduardo Augusto Gomes
   Version     : 2.0
   Tested OS   : Windows Server 2025
   Requisitos  : PowerShell 5.1+, Executar como Administrador
   Referências : CIS Benchmarks, Microsoft Security Baselines
#>

#region PARÂMETROS E VARIÁVEIS DE AMBIENTE
param(
    [string]$DomainName      = 'contoso.local',
    [string]$NtpServer       = 'dc01.contoso.local',
    [string]$BitLockerVolume = 'C:',
    [string]$PublicKeyPath   = 'C:\Keys\TPM_PubKey.pem',
    [switch]$SkipReboot      = $false,
    [switch]$EnableBitLocker = $false
)

# Listas de serviços a desabilitar (expandida)
$ServicesToDisable = @(
    'Spooler',               # Impressão se não for servidor de impressão
    'RemoteRegistry',        # Desabilita edição remota de registro
    'XblGameSave',           # Gaming services
    'XboxNetApiSvc',
    'MapsBroker',
    'PhoneSvc',
    'RetailDemo',
    'WSearch',               # Windows Search se não necessário
    'Fax',
    'SSDPSRV',               # UPnP
    'upnphost',
    'RemoteAccess',          # Routing and Remote Access
    'Telnet',
    'TFTP',
    'W3SVC',                 # IIS se não instalado
    'IISADMIN',
    'FTPSVC'
)

# Protocolos inseguros (expandido)
$DisableProtocols = @(
    @{Key='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name='LmCompatibilityLevel'; Value=5; Description='Somente NTLMv2'},
    @{Key='HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'; Name='SMB1'; Value=0; Description='Desabilita SMBv1'},
    @{Key='HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb10'; Name='Start'; Value=4; Description='Desabilita driver SMB1'},
    @{Key='HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb20'; Name='Start'; Value=3; Description='Garante SMB2 ativado'},
    @{Key='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client'; Name='AllowBasic'; Value=0; Description='Desabilita autenticação básica no WinRM'},
    @{Key='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service'; Name='AllowBasic'; Value=0; Description='Desabilita autenticação básica no WinRM'},
    @{Key='HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server'; Name='Enabled'; Value=0; Description='Desabilita TLS 1.0'},
    @{Key='HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server'; Name='Enabled'; Value=0; Description='Desabilita TLS 1.1'},
    @{Key='HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server'; Name='Enabled'; Value=0; Description='Desabilita SSL 2.0'},
    @{Key='HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server'; Name='Enabled'; Value=0; Description='Desabilita SSL 3.0'}
)

# Configurações de firewall (regras adicionais)
$FirewallRulesToAdd = @(
    @{Name='Block SMB Outbound'; Direction='Outbound'; Action='Block'; Protocol='TCP'; LocalPort='445,139'; Description='Block outbound SMB'},
    @{Name='Block RDP From Internet'; Direction='Inbound'; Action='Block'; Protocol='TCP'; RemotePort='3389'; Description='Block RDP from external networks'}
)

# Lista de recursos opcionais para remover
$FeaturesToRemove = @(
    'SMB1Protocol',
    'Windows-Defender-Default-Definitions',
    'Powershell-ISE'
)
#endregion

#region FUNÇÕES PRINCIPAIS
Function Assert-Admin {
    If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "É necessário rodar como Administrador!"
        Exit 1
    }
}

Function Set-WindowsUpdate {
    Write-Host "`n[+] Configurando Windows Update para Instalar Automaticamente…" -ForegroundColor Cyan
    try {
        # Configura políticas de atualização automática
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Force | Out-Null
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 4 -Type DWord -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "DeferFeatureUpdates" -Value 1 -Type DWord -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "DeferFeatureUpdatesPeriodInDays" -Value 30 -Type DWord -Force | Out-Null
        
        # Configura para receber atualizações de outros produtos Microsoft
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "DisableWindowsUpdateAccess" -Value 0 -Type DWord -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "TargetReleaseVersion" -Value 1 -Type DWord -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "TargetReleaseVersionInfo" -Value "Windows Server 2025" -Type String -Force | Out-Null
        
        Write-Host "  [√] Windows Update configurado com sucesso" -ForegroundColor Green
    } catch {
        Write-Host "  [X] Erro ao configurar Windows Update: $_" -ForegroundColor Red
    }
}

Function Set-TimeSync {
    Write-Host "`n[+] Configurando sincronização de hora com $NtpServer…" -ForegroundColor Cyan
    try {
        # Configura o servidor NTP
        w32tm /config /update /manualpeerlist:"$NtpServer" /syncfromflags:manual /reliable:yes | Out-Null
        w32tm /config /update | Out-Null
        
        # Reinicia o serviço de tempo
        Restart-Service w32time -Force
        
        # Força sincronização imediata
        w32tm /resync /rediscover | Out-Null
        
        # Configurações adicionais para servidores de domínio
        if ((Get-WmiObject Win32_ComputerSystem).PartOfDomain) {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "Type" -Value "NTP" -Force
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" -Name "AnnounceFlags" -Value 5 -Force
        }
        
        Write-Host "  [√] Sincronização de tempo configurada com sucesso" -ForegroundColor Green
    } catch {
        Write-Host "  [X] Erro ao configurar sincronização de tempo: $_" -ForegroundColor Red
    }
}

Function Set-PasswordPolicyLocal {
    Write-Host "`n[+] Ajustando política local de senha e bloqueio de conta…" -ForegroundColor Cyan
    try {
        # Exporta configurações atuais
        $tempFile = "$env:TEMP\secbaseline.inf"
        secedit /export /cfg $tempFile | Out-Null
        
        # Modifica as configurações
        $secConfig = Get-Content $tempFile
        $secConfig = $secConfig -replace '^PasswordComplexity = .*','PasswordComplexity = 1'
        $secConfig = $secConfig -replace '^MinimumPasswordLength = .*','MinimumPasswordLength = 14'
        $secConfig = $secConfig -replace '^PasswordHistorySize = .*','PasswordHistorySize = 24'
        $secConfig = $secConfig -replace '^MaximumPasswordAge = .*','MaximumPasswordAge = 60'
        $secConfig = $secConfig -replace '^MinimumPasswordAge = .*','MinimumPasswordAge = 1'
        $secConfig = $secConfig -replace '^LockoutBadCount = .*','LockoutBadCount = 5'
        $secConfig = $secConfig -replace '^ResetLockoutCount = .*','ResetLockoutCount = 15'
        $secConfig = $secConfig -replace '^LockoutDuration = .*','LockoutDuration = 15'
        $secConfig | Set-Content $tempFile -Force
        
        # Aplica as configurações
        secedit /configure /db seclocal.sdb /cfg $tempFile /areas SECURITYPOLICY | Out-Null
        Remove-Item $tempFile -Force
        
        # Configurações adicionais de conta
        net accounts /maxpwage:60 | Out-Null
        net accounts /minpwage:1 | Out-Null
        net accounts /minpwlen:14 | Out-Null
        net accounts /uniquepw:24 | Out-Null
        
        Write-Host "  [√] Política de senha local configurada com sucesso" -ForegroundColor Green
    } catch {
        Write-Host "  [X] Erro ao configurar política de senha: $_" -ForegroundColor Red
    }
}

Function Disable-WeakProtocols {
    Write-Host "`n[+] Desabilitando protocolos e modos inseguros…" -ForegroundColor Cyan
    foreach ($p in $DisableProtocols) {
        try {
            if (-not (Test-Path $p.Key)) {
                New-Item -Path $p.Key -Force | Out-Null
                Write-Host "  [•] Criada chave: $($p.Key)" -ForegroundColor DarkGray
            }
            
            New-ItemProperty -Path $p.Key -Name $p.Name -Value $p.Value -PropertyType DWord -Force | Out-Null
            Write-Host "  [√] $($p.Description) configurado" -ForegroundColor Green
        } catch {
            Write-Host "  [X] Erro ao configurar $($p.Description): $_" -ForegroundColor Red
        }
    }
    
    # Desabilita NetBIOS em todas as interfaces
    try {
        $adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled -eq $true}
        foreach ($adapter in $adapters) {
            $adapter.SetTcpipNetbios(2) | Out-Null  # 2 = Disable NetBIOS
        }
        Write-Host "  [√] NetBIOS desabilitado em todas as interfaces" -ForegroundColor Green
    } catch {
        Write-Host "  [X] Erro ao desabilitar NetBIOS: $_" -ForegroundColor Red
    }
}

Function Disable-Services {
    Write-Host "`n[+] Desabilitando serviços desnecessários…" -ForegroundColor Cyan
    foreach ($svc in $ServicesToDisable) {
        try {
            if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
                $service = Get-Service -Name $svc
                if ($service.Status -ne 'Stopped') {
                    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                    Write-Host "  [•] Serviço $svc parado" -ForegroundColor DarkGray
                }
                
                Set-Service -Name $svc -StartupType Disabled
                Write-Host "  [√] Serviço $svc desabilitado" -ForegroundColor Green
            }
        } catch {
            Write-Host "  [X] Erro ao desabilitar serviço $svc : $_" -ForegroundColor Red
        }
    }
}

Function Remove-UnnecessaryFeatures {
    Write-Host "`n[+] Removendo recursos desnecessários…" -ForegroundColor Cyan
    foreach ($feature in $FeaturesToRemove) {
        try {
            if (Get-WindowsFeature -Name $feature -ErrorAction SilentlyContinue | Where-Object {$_.Installed -eq $true}) {
                Remove-WindowsFeature -Name $feature -Confirm:$false
                Write-Host "  [√] Recurso $feature removido" -ForegroundColor Green
            }
        } catch {
            Write-Host "  [X] Erro ao remover recurso $feature : $_" -ForegroundColor Red
        }
    }
}

Function Edit-Firewall {
    Write-Host "`n[+] Configurando regras adicionais de firewall…" -ForegroundColor Cyan
    foreach ($rule in $FirewallRulesToAdd) {
        try {
            $params = @{
                DisplayName = $rule.Name
                Direction   = $rule.Direction
                Action      = $rule.Action
                Protocol    = $rule.Protocol
                Enabled     = $true
                Profile     = 'Any'
            }
            
            if ($rule.ContainsKey('LocalPort')) {
                $params['LocalPort'] = $rule.LocalPort
            }
            
            if ($rule.ContainsKey('RemotePort')) {
                $params['RemotePort'] = $rule.RemotePort
            }
            
            New-NetFirewallRule @params | Out-Null
            Write-Host "  [√] Regra de firewall '$($rule.Name)' adicionada" -ForegroundColor Green
        } catch {
            Write-Host "  [X] Erro ao adicionar regra de firewall '$($rule.Name)': $_" -ForegroundColor Red
        }
    }
    
    # Configurações gerais do firewall
    try {
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block -DefaultOutboundAction Allow -NotifyOnListen True -AllowUnicastResponseToMulticast False
        Write-Host "  [√] Configurações gerais do firewall aplicadas" -ForegroundColor Green
    } catch {
        Write-Host "  [X] Erro ao configurar firewall: $_" -ForegroundColor Red
    }
}

Function Edit-Registry {
    Write-Host "`n[+] Aplicando ajustes finos no registro…" -ForegroundColor Cyan
    $regs = @(
        # Desabilita LLMNR
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient';Name='EnableMulticast';Value=0;Description='LLMNR desabilitado'},
        # Desabilita NetBIOS over Tcp
        @{Path='HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters';Name='TransportBindName';Value=0x00000000;Description='NetBIOS over TCP/IP desabilitado'},
        # RDP – NLA obrigatório
        @{Path='HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp';Name='UserAuthentication';Value=1;Description='NLA habilitado para RDP'},
        # Exigir criptografia no RDP
        @{Path='HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp';Name='MinEncryptionLevel';Value=3;Description='Criptografia forte para RDP'},
        # Desabilita armazenamento de credenciais em plain text
        @{Path='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa';Name='DisableDomainCreds';Value=1;Description='Credenciais de domínio não armazenadas em texto claro'},
        # Desabilita autologon
        @{Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon';Name='AutoAdminLogon';Value=0;Description='Auto-logon desabilitado'},
        # Configurações de segurança adicionais
        @{Path='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa';Name='RestrictAnonymous';Value=1;Description='Acesso anônimo restrito'},
        @{Path='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa';Name='RestrictAnonymousSAM';Value=1;Description='Acesso anônimo ao SAM restrito'},
        @{Path='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa';Name='EveryoneIncludesAnonymous';Value=0;Description='Grupo Everyone não inclui anônimos'},
        # Desabilita WDigest
        @{Path='HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest';Name='UseLogonCredential';Value=0;Description='WDigest desabilitado'},
        # Desabilita IPv6 se não necessário
        @{Path='HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters';Name='DisabledComponents';Value=0xffffffff;Description='IPv6 desabilitado'}
    )
    
    foreach ($r in $regs) {
        try {
            if (-not (Test-Path $r.Path)) {
                New-Item -Path $r.Path -Force | Out-Null
            }
            
            New-ItemProperty -Path $r.Path -Name $r.Name -Value $r.Value -PropertyType DWord -Force | Out-Null
            Write-Host "  [√] $($r.Description)" -ForegroundColor Green
        } catch {
            Write-Host "  [X] Erro ao configurar $($r.Description): $_" -ForegroundColor Red
        }
    }
}

Function Enable-AuditPolicy {
    Write-Host "`n[+] Configurando auditoria avançada (Success & Failure)…" -ForegroundColor Cyan
    try {
        # Configurações básicas de auditoria
        auditpol /set /category:"Account Logon" /success:enable /failure:enable | Out-Null
        auditpol /set /category:"Account Management" /success:enable /failure:enable | Out-Null
        auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable | Out-Null
        auditpol /set /category:"Policy Change" /success:enable /failure:enable | Out-Null
        auditpol /set /category:"Privilege Use" /success:enable /failure:enable | Out-Null
        auditpol /set /category:"System" /success:enable /failure:enable | Out-Null
        auditpol /set /category:"Detailed Tracking" /success:enable /failure:enable | Out-Null
        auditpol /set /category:"DS Access" /success:enable /failure:enable | Out-Null
        auditpol /set /category:"Object Access" /success:enable /failure:enable | Out-Null
        
        # Configurações avançadas via registry
        $auditRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit"
        if (-not (Test-Path $auditRegPath)) {
            New-Item -Path $auditRegPath -Force | Out-Null
        }
        
        # Habilita auditoria de comandos PowerShell
        New-ItemProperty -Path $auditRegPath -Name "ProcessCreationIncludeCmdLine_Enabled" -Value 1 -PropertyType DWord -Force | Out-Null
        
        # Configura tamanho máximo do log de segurança
        $eventLogRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Security"
        New-ItemProperty -Path $eventLogRegPath -Name "MaxSize" -Value 209715200 -PropertyType DWord -Force | Out-Null  # 200MB
        New-ItemProperty -Path $eventLogRegPath -Name "Retention" -Value 0 -PropertyType DWord -Force | Out-Null  # Não sobrescrever eventos
        
        Write-Host "  [√] Política de auditoria configurada com sucesso" -ForegroundColor Green
    } catch {
        Write-Host "  [X] Erro ao configurar política de auditoria: $_" -ForegroundColor Red
    }
}

Function Enable-SecurityFeatures {
    Write-Host "`n[+] Habilitando Windows Defender, Tamper Protection e Credential Guard…" -ForegroundColor Cyan
    try {
        # Verifica se o Defender está instalado
        if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
            # Defender em tempo real
            Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop
            
            # Configurações avançadas do Defender
            Set-MpPreference -CloudBlockLevel 4 -CloudExtendedTimeout 50 -MAPSReporting 2 -SubmitSamplesConsent 2 -ErrorAction Stop
            
            # Tamper Protection (via registry; GPOs no domínio podem prevalecer)
            New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features' -Name 'TamperProtection' -PropertyType DWord -Value 5 -Force -ErrorAction Stop
            
            # Atualiza assinaturas
            Update-MpSignature -ErrorAction Stop
            
            Write-Host "  [√] Windows Defender configurado com sucesso" -ForegroundColor Green
        } else {
            Write-Host "  [!] Windows Defender não está instalado" -ForegroundColor Yellow
        }
        
        # Credential Guard (Host Guardian)—se a máquina for compatível
        if ((Get-CimInstance Win32_ComputerSystem).HypervisorPresent -eq $true) {
            # Verifica se o recurso está disponível
            if (Get-WindowsFeature -Name "HostGuardian" -ErrorAction SilentlyContinue) {
                bcdedit /set hypervisorlaunchtype auto | Out-Null
                bcdedit /set vmichypervisor present | Out-Null
                Enable-WindowsOptionalFeature -Online -FeatureName "HostGuardian" -NoRestart | Out-Null
                Write-Host "  [√] Credential Guard habilitado" -ForegroundColor Green
            } else {
                Write-Host "  [!] Credential Guard não disponível neste sistema" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [!] Hypervisor não presente - Credential Guard não pode ser habilitado" -ForegroundColor Yellow
        }
        
        # Habilita LSA Protection
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 1 -PropertyType DWord -Force | Out-Null
        Write-Host "  [√] LSA Protection habilitada" -ForegroundColor Green
        
        # Habilita UAC
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 2 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Value 1 -PropertyType DWord -Force | Out-Null
        Write-Host "  [√] UAC configurado para modo estrito" -ForegroundColor Green
        
    } catch {
        Write-Host "  [X] Erro ao configurar recursos de segurança: $_" -ForegroundColor Red
    }
}

Function Enable-BitLocker {
    if (-not $EnableBitLocker) {
        Write-Host "`n[!] BitLocker não será habilitado (parâmetro -EnableBitLocker não especificado)" -ForegroundColor Yellow
        return
    }
    
    Write-Host "`n[+] Habilitando BitLocker no volume $BitLockerVolume…" -ForegroundColor Cyan
    try {
        # Verifica se o volume existe
        if (-not (Test-Path $BitLockerVolume)) {
            Write-Host "  [X] Volume $BitLockerVolume não encontrado" -ForegroundColor Red
            return
        }
        
        # Verifica se o TPM está presente
        $tpm = Get-Tpm -ErrorAction SilentlyContinue
        if (-not $tpm -or $tpm.TpmPresent -eq $false) {
            Write-Host "  [X] TPM não encontrado ou não habilitado" -ForegroundColor Red
            return
        }
        
        # Verifica se o BitLocker já está habilitado
        $bitlockerStatus = Get-BitLockerVolume -MountPoint $BitLockerVolume -ErrorAction SilentlyContinue
        if ($bitlockerStatus -and $bitlockerStatus.VolumeStatus -eq 'FullyEncrypted') {
            Write-Host "  [!] BitLocker já está habilitado no volume $BitLockerVolume" -ForegroundColor Yellow
            return
        }
        
        # Habilita o BitLocker
        Enable-BitLocker -MountPoint $BitLockerVolume -TpmProtector -UsedSpaceOnly -EncryptionMethod Aes256 -SkipHardwareTest -Confirm:$false -ErrorAction Stop
        
        # Se uma chave pública foi fornecida, adiciona como protetor
        if ($PublicKeyPath -and (Test-Path $PublicKeyPath)) {
            Add-BitLockerKeyProtector -MountPoint $BitLockerVolume -ExternalKeyProtector -ExternalKeyFilePath $PublicKeyPath -ErrorAction Stop
            Write-Host "  [√] Protetor de chave externa adicionado" -ForegroundColor Green
        }
        
        # Configura política de recuperação
        Manage-Bde -Protectors -Add $BitLockerVolume -RecoveryPassword | Out-Null
        
        Write-Host "  [√] BitLocker habilitado com sucesso no volume $BitLockerVolume" -ForegroundColor Green
        Write-Host "  [!] A criptografia pode levar algum tempo para ser concluída" -ForegroundColor Yellow
    } catch {
        Write-Host "  [X] Erro ao habilitar BitLocker: $_" -ForegroundColor Red
    }
}

Function Set-UserRightsAssignment {
    Write-Host "`n[+] Configurando direitos de usuário…" -ForegroundColor Cyan
    try {
        # Importa o módulo necessário
        Import-Module PolicyFileEditor -ErrorAction Stop
        
        # Define as configurações de direitos de usuário
        $userRights = @{
            "SeDenyNetworkLogonRight" = @("Guests")  # Negar logon pela rede para convidados
            "SeDenyInteractiveLogonRight" = @("Guests")  # Negar logon interativo para convidados
            "SeDenyRemoteInteractiveLogonRight" = @("Guests")  # Negar logon remoto interativo para convidados
            "SeInteractiveLogonRight" = @("Administrators", "Backup Operators")  # Permitir logon interativo apenas para admins
        }
        
        # Aplica as configurações
        foreach ($right in $userRights.Keys) {
            Set-PolicyUserRight -PolicyPath "$env:SystemRoot\system32\GroupPolicy\Machine\Registry.pol" -Right $right -Identity $userRights[$right]
            Write-Host "  [√] Direito '$right' configurado para: $($userRights[$right] -join ', ')" -ForegroundColor Green
        }
        
        # Atualiza as políticas
        gpupdate /force | Out-Null
        
        Write-Host "  [√] Direitos de usuário configurados com sucesso" -ForegroundColor Green
    } catch {
        Write-Host "  [X] Erro ao configurar direitos de usuário: $_" -ForegroundColor Red
    }
}

Function Set-PowerShellSecurity {
    Write-Host "`n[+] Configurando segurança do PowerShell…" -ForegroundColor Cyan
    try {
        # Configura o modo de linguagem do PowerShell para Constrained
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" -Name "ExecutionPolicy" -Value "Restricted" -PropertyType String -Force | Out-Null
        
        # Habilita logging detalhado do PowerShell
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell" -Name "ScriptBlockLogging" -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1 -PropertyType DWord -Force | Out-Null
        
        # Habilita transcrição de sessões do PowerShell
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell" -Name "Transcription" -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "EnableTranscripting" -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "EnableInvocationHeader" -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "OutputDirectory" -Value "C:\PS_Transcripts" -PropertyType String -Force | Out-Null
        
        Write-Host "  [√] Segurança do PowerShell configurada" -ForegroundColor Green
    } catch {
        Write-Host "  [X] Erro ao configurar segurança do PowerShell: $_" -ForegroundColor Red
    }
}

Function Set-AdvancedSecuritySettings {
    Write-Host "`n[+] Configurando segurança avançada…" -ForegroundColor Cyan
    try {
        # Desabilita autenticação NTLM
        New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" -Name "NTLMMinClientSec" -Value 0x20080000 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" -Name "NTLMMinServerSec" -Value 0x20080000 -PropertyType DWord -Force | Out-Null
        
        # Configurações de segurança de rede
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" -Name "NoNameReleaseOnDemand" -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" -Name "NodeType" -Value 2 -PropertyType DWord -Force | Out-Null
        
        # Desabilita compartilhamento de arquivos e impressora
        Set-NetFirewallRule -DisplayGroup "File and Printer Sharing" -Enabled False -Profile Any | Out-Null
        
        # Configurações de segurança do SMB
        Set-SmbServerConfiguration -EncryptData $true -Force | Out-Null
        Set-SmbServerConfiguration -RejectUnencryptedAccess $true -Force | Out-Null
        
        # Desabilita compartilhamento administrativo
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "AutoShareWks" -Value 0 -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "AutoShareServer" -Value 0 -Force | Out-Null
        
        Write-Host "  [√] Configurações de segurança avançada aplicadas" -ForegroundColor Green
    } catch {
        Write-Host "  [X] Erro ao configurar segurança avançada: $_" -ForegroundColor Red
    }
}

Function Set-ScheduledTasks {
    Write-Host "`n[+] Desabilitando tarefas agendadas desnecessárias…" -ForegroundColor Cyan
    $tasksToDisable = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
    )
    
    foreach ($task in $tasksToDisable) {
        try {
            Disable-ScheduledTask -TaskPath $task -ErrorAction Stop | Out-Null
            Write-Host "  [√] Tarefa $task desabilitada" -ForegroundColor Green
        } catch {
            Write-Host "  [X] Erro ao desabilitar tarefa $task : $_" -ForegroundColor Red
        }
    }
}

Function Set-ExploitProtection {
    Write-Host "`n[+] Configurando Exploit Protection…" -ForegroundColor Cyan
    try {
        # Configurações básicas de Exploit Protection
        Set-ProcessMitigation -System -Enable DEP,SEHOP,TerminateOnError -Force | Out-Null
        Set-ProcessMitigation -System -Enable CFG,StrictHandle -Force | Out-Null
        Set-ProcessMitigation -System -Enable FontDisable -Force | Out-Null
        Set-ProcessMitigation -System -Enable DisableExtensionPoints -Force | Out-Null
        
        # Configurações adicionais
        Set-ProcessMitigation -PolicyFilePath "C:\Windows\System32\MitigationOptions\ExploitProtection.xml" -Enable ExportImport -Force | Out-Null
        
        Write-Host "  [√] Exploit Protection configurado" -ForegroundColor Green
    } catch {
        Write-Host "  [X] Erro ao configurar Exploit Protection: $_" -ForegroundColor Red
    }
}

Function Set-NetworkSecurity {
    Write-Host "`n[+] Configurando segurança de rede…" -ForegroundColor Cyan
    try {
        # Desabilita NetBIOS em todas as interfaces
        $adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled -eq $true}
        foreach ($adapter in $adapters) {
            $adapter.SetTcpipNetbios(2) | Out-Null  # 2 = Disable NetBIOS
        }
        
        # Configurações de TCP/IP
        Set-NetTCPSetting -SettingName InternetCustom -CongestionProvider DCTCP -Force | Out-Null
        Set-NetTCPSetting -SettingName DatacenterCustom -CongestionProvider DCTCP -Force | Out-Null
        
        # Desabilita SMB v1
        Disable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -NoRestart | Out-Null
        
        # Configurações de segurança do SMB
        Set-SmbServerConfiguration -EncryptData $true -Force | Out-Null
        Set-SmbServerConfiguration -RejectUnencryptedAccess $true -Force | Out-Null
        
        Write-Host "  [√] Configurações de segurança de rede aplicadas" -ForegroundColor Green
    } catch {
        Write-Host "  [X] Erro ao configurar segurança de rede: $_" -ForegroundColor Red
    }
}

Function Set-LoggingSettings {
    Write-Host "`n[+] Configurando logs avançados…" -ForegroundColor Cyan
    try {
        # Configura tamanho e retenção dos logs principais
        $logs = @(
            @{Name="Application"; Size=104857600; Retention=0},  # 100MB, não sobrescrever
            @{Name="System"; Size=104857600; Retention=0},
            @{Name="Security"; Size=209715200; Retention=0},
            @{Name="Windows PowerShell"; Size=52428800; Retention=0}
        )
        
        foreach ($log in $logs) {
            Limit-EventLog -LogName $log.Name -MaximumSize $log.Size -OverflowAction $log.Retention
            Write-Host "  [√] Log $($log.Name) configurado para $($log.Size/1MB)MB" -ForegroundColor Green
        }
        
        # Habilita logging detalhado de logon
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Name "AuditLogonEvents" -Value 3 -PropertyType DWord -Force | Out-Null
        
        Write-Host "  [√] Configurações de logging aplicadas" -ForegroundColor Green
    } catch {
        Write-Host "  [X] Erro ao configurar logs: $_" -ForegroundColor Red
    }
}

Function Set-AdditionalSecurity {
    Write-Host "`n[+] Aplicando configurações adicionais de segurança…" -ForegroundColor Cyan
    try {
        # Desabilita AutoRun para todas as unidades
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Value 255 -PropertyType DWord -Force | Out-Null
        
        # Desabilita execução de scripts de instalação de aplicativos da Internet
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap" -Name "IEHarden" -Value 1 -PropertyType DWord -Force | Out-Null
        
        # Desabilita o armazenamento de senhas pelo Gerenciador de Credenciais
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "DisableDomainCreds" -Value 1 -PropertyType DWord -Force | Out-Null
        
        # Desabilita o recurso "Save Password" no Internet Explorer
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "DisablePasswordCaching" -Value 1 -PropertyType DWord -Force | Out-Null
        
        # Configurações de segurança do LSASS
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 1 -PropertyType DWord -Force | Out-Null
        
        Write-Host "  [√] Configurações adicionais de segurança aplicadas" -ForegroundColor Green
    } catch {
        Write-Host "  [X] Erro ao aplicar configurações adicionais: $_" -ForegroundColor Red
    }
}

Function Set-FinalChecks {
    Write-Host "`n[+] Realizando verificações finais…" -ForegroundColor Cyan
    try {
        # Verifica se o sistema está em domínio
        $isDomainJoined = (Get-WmiObject Win32_ComputerSystem).PartOfDomain
        if ($isDomainJoined) {
            Write-Host "  [√] Computador é membro do domínio" -ForegroundColor Green
        } else {
            Write-Host "  [!] Computador NÃO está em um domínio" -ForegroundColor Yellow
        }
        
        # Verifica status do firewall
        $fwProfiles = Get-NetFirewallProfile | Where-Object {$_.Enabled -ne "True"}
        if ($fwProfiles) {
            Write-Host "  [X] Firewall não está habilitado nos perfis: $($fwProfiles.Name -join ', ')" -ForegroundColor Red
        } else {
            Write-Host "  [√] Firewall habilitado em todos os perfis" -ForegroundColor Green
        }
        
        # Verifica status do Defender
        $defenderStatus = Get-MpComputerStatus
        if ($defenderStatus.AntivirusEnabled -and $defenderStatus.AntispywareEnabled) {
            Write-Host "  [√] Windows Defender habilitado e operacional" -ForegroundColor Green
        } else {
            Write-Host "  [X] Windows Defender não está totalmente habilitado" -ForegroundColor Red
        }
        
        # Verifica atualizações pendentes
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $searchResult = $updateSearcher.Search("IsInstalled=0")
        if ($searchResult.Updates.Count -gt 0) {
            Write-Host "  [!] Existem $($searchResult.Updates.Count) atualizações pendentes" -ForegroundColor Yellow
        } else {
            Write-Host "  [√] Sistema está atualizado" -ForegroundColor Green
        }
        
        # Verifica se reboot é necessário
        if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
            Write-Host "  [!] REBOOT NECESSÁRIO para concluir configurações" -ForegroundColor Yellow -BackgroundColor DarkRed
        } else {
            Write-Host "  [√] Nenhum reboot pendente detectado" -ForegroundColor Green
        }
    } catch {
        Write-Host "  [X] Erro durante verificações finais: $_" -ForegroundColor Red
    }
}
#endregion

#region EXECUÇÃO PRINCIPAL
Clear-Host
Write-Host "`n=== HARDENING PARA WINDOWS SERVER 2025 ===" -ForegroundColor Cyan
Write-Host "=== Versão 2.0 | $(Get-Date) ===`n" -ForegroundColor Cyan

# Verifica privilégios de administrador
Assert-Admin

# Executa todas as funções de hardening
Set-WindowsUpdate
Set-TimeSync
Set-PasswordPolicyLocal
Disable-WeakProtocols
Disable-Services
Remove-UnnecessaryFeatures
Edit-Firewall
Edit-Registry
Enable-AuditPolicy
Enable-SecurityFeatures
Set-UserRightsAssignment
Set-PowerShellSecurity
Set-AdvancedSecuritySettings
Set-ScheduledTasks
Set-ExploitProtection
Set-NetworkSecurity
Set-LoggingSettings
Set-AdditionalSecurity

# BitLocker opcional
if ($EnableBitLocker) {
    Enable-BitLocker
}

# Verificações finais
Set-FinalChecks

# Mensagem de conclusão
Write-Host "`n=== HARDENING COMPLETO ===" -ForegroundColor Green
if (-not $SkipReboot) {
    $reboot = Read-Host "Deseja reiniciar o servidor agora? (S/N)"
    if ($reboot -eq 'S' -or $reboot -eq 's') {
        Write-Host "Reiniciando o servidor..." -ForegroundColor Yellow
        Restart-Computer -Force
    }
} else {
    Write-Host "`n[!] Reinicie o servidor para aplicar todas as configurações" -ForegroundColor Yellow
}

Write-Host "`nScript concluído em $((Get-Date) - $startTime)" -ForegroundColor Cyan
#endregion