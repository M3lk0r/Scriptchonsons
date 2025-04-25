<#
.SYNOPSIS
   Hardening básico e avançado para Windows Server 2025 membro de domínio.
.DESCRIPTION
   Aplica configurações de segurança, políticas de senha, desabilita protocolos e serviços inseguros,
   habilita auditoria, BitLocker, Defender, atualizações automáticas, horário sincronizado no DC etc.
   Inclui configurações adicionais para CIS Benchmark Level 1 e recomendações da Microsoft.
.NOTES
   FileName    : Hardening-WindowsServer2025.ps1
   Author      : Eduardo Augusto Gomes (ajustado)
   Version     : 2.1
   Tested OS   : Windows Server 2025
   Requisitos  : PowerShell 5.1+, Executar como Administrador
   Referências : CIS Benchmarks, Microsoft Security Baselines
#>

#region PARÂMETROS
param(
    [string]$DomainName = 'contoso.local',
    [string]$NtpServer = 'dc01.contoso.local',
    [string]$BitLockerVolume = 'C:',
    [string]$PublicKeyPath = 'C:\Keys\TPM_PubKey.pem',
    [switch]$SkipReboot,
    [switch]$EnableBitLocker
)
#endregion

#region VARIÁVEIS GLOBAIS
$ServicesToDisable = @(
    'Spooler', 'RemoteRegistry', 'XblGameSave', 'XboxNetApiSvc',
    'MapsBroker', 'PhoneSvc', 'RetailDemo', 'WSearch', 'Fax',
    'SSDPSRV', 'upnphost', 'RemoteAccess', 'Telnet', 'TFTP',
    'W3SVC', 'IISADMIN', 'FTPSVC'
)
$DisableProtocols = @(
    @{Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'LmCompatibilityLevel'; Value = 5; Description = 'Somente NTLMv2' },
    @{Key = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'; Name = 'SMB1'; Value = 0; Description = 'Desabilita SMBv1' },
    @{Key = 'HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb10'; Name = 'Start'; Value = 4; Description = 'Desabilita driver SMB1' },
    @{Key = 'HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb20'; Name = 'Start'; Value = 3; Description = 'Garante SMB2 ativado' },
    @{Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client'; Name = 'AllowBasic'; Value = 0; Description = 'Desabilita autenticação básica no WinRM (Client)' },
    @{Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service'; Name = 'AllowBasic'; Value = 0; Description = 'Desabilita autenticação básica no WinRM (Service)' },
    @{Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client'; Name = 'Enabled'; Value = 0; Description = 'Desabilita TLS 1.0 Client' },
    @{Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server'; Name = 'Enabled'; Value = 0; Description = 'Desabilita TLS 1.0 Server' },
    @{Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client'; Name = 'Enabled'; Value = 0; Description = 'Desabilita TLS 1.1 Client' },
    @{Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server'; Name = 'Enabled'; Value = 0; Description = 'Desabilita TLS 1.1 Server' },
    @{Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client'; Name = 'Enabled'; Value = 0; Description = 'Desabilita SSL 2.0 Client' },
    @{Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server'; Name = 'Enabled'; Value = 0; Description = 'Desabilita SSL 2.0 Server' },
    @{Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client'; Name = 'Enabled'; Value = 0; Description = 'Desabilita SSL 3.0 Client' },
    @{Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server'; Name = 'Enabled'; Value = 0; Description = 'Desabilita SSL 3.0 Server' }
)
$FirewallRulesToAdd = @(
    @{Name = 'Block SMB Outbound'; Direction = 'Outbound'; Action = 'Block'; Protocol = 'TCP'; RemotePort = '445,139'; Profile = 'Any'; Description = 'Bloqueia SMB de saída' },
    @{Name = 'Block RDP From Internet'; Direction = 'Inbound'; Action = 'Block'; Protocol = 'TCP'; RemotePort = '3389'; Profile = 'Public'; Description = 'Bloqueia RDP em perfil Público' }
)
$FeaturesToRemove = @('SMB1Protocol', 'Powershell-ISE')
#endregion

#region UTILITÁRIOS
Function Assert-Admin {
    If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'É necessário rodar como Administrador!'
    }
}

Function Disable-NetBIOS {
    Write-Host "`n[+] Desabilitando NetBIOS em todas as interfaces…" -ForegroundColor Cyan
    Try {
        $adapters = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled }
        foreach ($a in $adapters) {
            $a.SetTcpipNetbios(2) | Out-Null  # 2 = Disable
        }
        Write-Host "  [√] NetBIOS desabilitado" -ForegroundColor Green
    }
    Catch {
        Write-Host "  [X] Erro ao desabilitar NetBIOS: $_" -ForegroundColor Red
    }
}
#endregion

#region FUNÇÕES DE HARDENING
Function Set-WindowsUpdate {
    Write-Host "`n[+] Configurando Windows Update…" -ForegroundColor Cyan
    Try {
        $base = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        New-Item -Path $base -Force | Out-Null
        New-Item -Path "$base\AU" -Force | Out-Null
        New-ItemProperty -Path "$base\AU" -Name 'AUOptions' -Value 4 -Type DWord -Force | Out-Null
        New-ItemProperty -Path "$base\AU" -Name 'NoAutoRebootWithLoggedOnUsers' -Value 1 -Type DWord -Force | Out-Null
        New-ItemProperty -Path $base     -Name 'DeferFeatureUpdates' -Value 1 -Type DWord -Force | Out-Null
        New-ItemProperty -Path $base     -Name 'DeferFeatureUpdatesPeriodInDays' -Value 30 -Type DWord -Force | Out-Null
        New-ItemProperty -Path $base     -Name 'DisableWindowsUpdateAccess' -Value 0 -Type DWord -Force | Out-Null
        New-ItemProperty -Path $base     -Name 'TargetReleaseVersion' -Value 1 -Type DWord -Force | Out-Null
        New-ItemProperty -Path $base     -Name 'TargetReleaseVersionInfo' -Value 'Windows Server 2025' -Type String -Force | Out-Null
        Write-Host "  [√] Windows Update OK" -ForegroundColor Green
    }
    Catch {
        Write-Host "  [X] Windows Update: $_" -ForegroundColor Red
    }
}

Function Set-TimeSync {
    Write-Host "`n[+] Configurando Sincronização de Hora…" -ForegroundColor Cyan
    Try {
        w32tm /config /manualpeerlist:$NtpServer /syncfromflags:manual /reliable:yes /update | Out-Null
        Restart-Service w32time -ErrorAction Stop
        Start-Sleep -Seconds 5
        w32tm /resync /rediscover | Out-Null

        $cs = Get-CimInstance Win32_ComputerSystem
        if ($cs.PartOfDomain) {
            Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters' -Name 'Type' -Value 'NTP' -Force
            Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config'     -Name 'AnnounceFlags' -Value 5 -Force
        }
        Write-Host "  [√] TimeSync OK" -ForegroundColor Green
    }
    Catch {
        Write-Host "  [X] TimeSync: $_" -ForegroundColor Red
    }
}

Function Set-PasswordPolicyLocal {
    Write-Host "`n[+] Ajustando Política Local de Senha…" -ForegroundColor Cyan
    Try {
        $temp = "$env:TEMP\secbaseline.inf"
        secedit /export /cfg $temp | Out-Null
        (Get-Content $temp) -replace '^PasswordComplexity = .*', 'PasswordComplexity = 1' `
            -replace '^MinimumPasswordLength = .*', 'MinimumPasswordLength = 14' `
            -replace '^PasswordHistorySize = .*', 'PasswordHistorySize = 24' `
            -replace '^MaximumPasswordAge = .*', 'MaximumPasswordAge = 60' `
            -replace '^MinimumPasswordAge = .*', 'MinimumPasswordAge = 1' `
            -replace '^LockoutBadCount = .*', 'LockoutBadCount = 5' `
            -replace '^ResetLockoutCount = .*', 'ResetLockoutCount = 15' `
            -replace '^LockoutDuration = .*', 'LockoutDuration = 15' |
        Set-Content $temp -Force
        secedit /configure /db "$env:windir\security\database\secedit.sdb" /cfg $temp /areas SECURITYPOLICY | Out-Null
        Remove-Item $temp -Force

        net accounts /maxpwage:60 /minpwage:1 /minpwlen:14 /uniquepw:24 | Out-Null
        Write-Host "  [√] PasswordPolicy OK" -ForegroundColor Green
    }
    Catch {
        Write-Host "  [X] PasswordPolicy: $_" -ForegroundColor Red
    }
}

Function Disable-WeakProtocols {
    Write-Host "`n[+] Desabilitando Protocolos Fracos…" -ForegroundColor Cyan
    foreach ($p in $DisableProtocols) {
        Try {
            if (-not (Test-Path $p.Key)) { New-Item -Path $p.Key -Force | Out-Null }
            New-ItemProperty -Path $p.Key -Name $p.Name -Value $p.Value -PropertyType DWord -Force | Out-Null
            Write-Host "  [√] $($p.Description)" -ForegroundColor Green
        }
        Catch {
            Write-Host "  [X] $($p.Description): $_" -ForegroundColor Red
        }
    }
    Disable-NetBIOS
}

Function Disable-Services {
    Write-Host "`n[+] Desabilitando Serviços Inseguros…" -ForegroundColor Cyan
    foreach ($svc in $ServicesToDisable) {
        Try {
            $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($s) {
                if ($s.Status -ne 'Stopped') { Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue }
                Set-Service  -Name $svc -StartupType Disabled
                Write-Host "  [√] $svc Disabled" -ForegroundColor Green
            }
        }
        Catch {
            Write-Host "  [X] $($svc): $_" -ForegroundColor Red
        }
    }
}

Function Remove-UnnecessaryFeatures {
    Write-Host "`n[+] Removendo Features… " -ForegroundColor Cyan
    foreach ($feature in $FeaturesToRemove) {
        $f = Get-WindowsFeature -Name $feature -ErrorAction SilentlyContinue
        if ($f -and $f.Installed) {
            Try {
                Uninstall-WindowsFeature -Name $feature -IncludeAllSubFeature -ErrorAction Stop | Out-Null
                Write-Host "  [√] Feature $($feature) removida" -ForegroundColor Green
            }
            Catch {
                Write-Host "  [X] Feature $($feature): $_" -ForegroundColor Red
            }
        }
    }
}

Function Edit-Firewall {
    Write-Host "`n[+] Configurando Firewall…" -ForegroundColor Cyan
    foreach ($r in $FirewallRulesToAdd) {
        Try {
            $params = @{
                DisplayName = $r.Name
                Direction   = $r.Direction
                Action      = $r.Action
                Protocol    = $r.Protocol
                Profile     = $r.Profile
                Enabled     = $true
            }
            if ($r.ContainsKey('LocalPort')) { $params['LocalPort'] = $r.LocalPort }
            if ($r.ContainsKey('RemotePort')) { $params['RemotePort'] = $r.RemotePort }
            New-NetFirewallRule @params | Out-Null
            Write-Host "  [√] FW Rule '$($r.Name)'" -ForegroundColor Green
        }
        Catch {
            Write-Host "  [X] FW Rule '$($r.Name)': $_" -ForegroundColor Red
        }
    }
    Try {
        Set-NetFirewallProfile -Profile Domain, Private, Public -DefaultInboundAction Block -DefaultOutboundAction Allow -ErrorAction Stop
        Write-Host "  [√] Firewall Profiles OK" -ForegroundColor Green
    }
    Catch {
        Write-Host "  [X] FW Profiles: $_" -ForegroundColor Red
    }
}

Function Edit-Registry {
    Write-Host "`n[+] Ajustes Finitos no Registry…" -ForegroundColor Cyan
    $regs = @(
        @{Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'; Name = 'EnableMulticast'; Value = 0; Description = 'LLMNR desabilitado' },
        @{Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters'; Name = 'NodeType'; Value = 2; Description = 'NBNS HOTDOT only' },
        @{Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'; Name = 'AutoShareServer'; Value = 0; Description = 'Desabilita shares admin' },
        @{Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'; Name = 'AutoShareWks'; Value = 0; Description = 'Desabilita shares admin' },
        @{Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'; Name = 'UserAuthentication'; Value = 1; Description = 'NLA obrigatório' },
        @{Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'; Name = 'MinEncryptionLevel'; Value = 3; Description = 'Criptografia RDP forte' },
        @{Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'DisableDomainCreds'; Value = 1; Description = 'Não armazena credenciais em texto' },
        @{Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'RestrictAnonymous'; Value = 1; Description = 'Sem acesso anônimo' },
        @{Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'RunAsPPL'; Value = 1; Description = 'LSA protegido como PPL' },
        @{Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest'; Name = 'UseLogonCredential'; Value = 0; Description = 'WDigest off' },
        @{Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'; Name = 'DisabledComponents'; Value = 0xFFFFFFFF; Description = 'IPv6 desabilitado' },
        @{Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'; Name = 'AutoAdminLogon'; Value = 0; Description = 'Autologon off' }
    )
    foreach ($r in $regs) {
        Try {
            if (-not (Test-Path $r.Path)) { New-Item -Path $r.Path -Force | Out-Null }
            New-ItemProperty -Path $r.Path -Name $r.Name -Value $r.Value -PropertyType DWord -Force | Out-Null
            Write-Host "  [√] $($r.Description)" -ForegroundColor Green
        }
        Catch {
            Write-Host "  [X] $($r.Description): $_" -ForegroundColor Red
        }
    }
}

Function Enable-AuditPolicy {
    Write-Host "`n[+] Configurando Auditoria avançada…" -ForegroundColor Cyan
    Try {
        $cats = @(
            "Account Logon", "Account Management", "Logon/Logoff",
            "Policy Change", "Privilege Use", "System",
            "Detailed Tracking", "Object Access", "DS Access"
        )
        foreach ($c in $cats) { auditpol /set /category:"$c" /success:enable /failure:enable | Out-Null }
        # ScriptBlockLogging via GPO
        $base = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell'
        New-Item -Path "$base\ScriptBlockLogging" -Force | Out-Null
        New-ItemProperty -Path "$base\ScriptBlockLogging" -Name 'EnableScriptBlockLogging' -Value 1 -PropertyType DWord -Force | Out-Null
        # Event Log max size
        $evt = 'HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Security'
        New-ItemProperty -Path $evt -Name MaxSize -Value 209715200 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $evt -Name Retention -Value 0 -PropertyType DWord -Force | Out-Null
        Write-Host "  [√] AuditPolicy OK" -ForegroundColor Green
    }
    Catch {
        Write-Host "  [X] AuditPolicy: $_" -ForegroundColor Red
    }
}

Function Enable-SecurityFeatures {
    Write-Host "`n[+] Habilitando Defender, UAC e Credential Guard…" -ForegroundColor Cyan
    Try {
        if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
            Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop
            Set-MpPreference -CloudBlockLevel 4 -MAPSReporting 2 -SubmitSamplesConsent 2 -ErrorAction Stop
            Update-MpSignature -ErrorAction Stop
            Write-Host "  [√] Defender OK" -ForegroundColor Green
        }
        # UAC
        $sysPol = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        New-ItemProperty -Path $sysPol -Name 'EnableLUA' -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $sysPol -Name 'ConsentPromptBehaviorAdmin' -Value 2 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $sysPol -Name 'PromptOnSecureDesktop' -Value 1 -PropertyType DWord -Force | Out-Null
        Write-Host "  [√] UAC Strict" -ForegroundColor Green

        # Credential Guard (simplificado)
        $cs = Get-CimInstance Win32_ComputerSystem
        if ($cs.HypervisorPresent) {
            Try {
                Enable-WindowsOptionalFeature -Online -FeatureName 'DeviceGuard', 'HypervisorPlatform' -NoRestart -ErrorAction Stop | Out-Null
                Write-Host "  [√] Credential Guard habilitado" -ForegroundColor Green
            }
            Catch {
                Write-Host "  [!] Credential Guard falhou: $_" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "  [!] Hypervisor não presente - Credential Guard OFF" -ForegroundColor Yellow
        }
    }
    Catch {
        Write-Host "  [X] SecurityFeatures: $_" -ForegroundColor Red
    }
}

Function Enable-BitLocker {
    Write-Host "`n[+] Habilitando BitLocker…" -ForegroundColor Cyan
    if (-not $EnableBitLocker) {
        Write-Host "  [!] SkipBitLocker" -ForegroundColor Yellow
        return
    }
    Try {
        $vol = Get-BitLockerVolume -MountPoint $BitLockerVolume -ErrorAction Stop
        if ($vol.VolumeStatus -eq 'FullyEncrypted') {
            Write-Host "  [!] Já criptografado" -ForegroundColor Yellow
            return
        }
        $tpm = Get-Tpm -ErrorAction Stop
        if (-not $tpm.TpmReady) { throw 'TPM não pronto' }
        Enable-BitLocker -MountPoint $BitLockerVolume -TpmProtector -EncryptionMethod Aes256 -Confirm:$false -ErrorAction Stop
        if (Test-Path $PublicKeyPath) {
            Add-BitLockerKeyProtector -MountPoint $BitLockerVolume -ExternalKeyProtector -ExternalKeyFilePath $PublicKeyPath
        }
        Write-Host "  [√] BitLocker iniciado" -ForegroundColor Green
    }
    Catch {
        Write-Host "  [X] BitLocker: $_" -ForegroundColor Red
    }
}

Function Set-UserRightsAssignment {
    Write-Host "`n[+] Configurando User Rights…" -ForegroundColor Cyan
    if (-not (Get-Module -ListAvailable PolicyFileEditor)) {
        Write-Host "  [!] PolicyFileEditor não instalado; pulando UserRights" -ForegroundColor Yellow
        return
    }
    Try {
        Import-Module PolicyFileEditor -ErrorAction Stop
        $mapping = @{
            SeDenyNetworkLogonRight           = @('Guests')
            SeDenyInteractiveLogonRight       = @('Guests')
            SeDenyRemoteInteractiveLogonRight = @('Guests')
            SeInteractiveLogonRight           = @('Administrators', 'Backup Operators')
        }
        $pol = "$env:windir\system32\GroupPolicy\Machine\Registry.pol"
        foreach ($right in $mapping.Keys) {
            Set-PolicyUserRight -PolicyPath $pol -Right $right -Identity $mapping[$right]
        }
        gpupdate /force | Out-Null
        Write-Host "  [√] UserRights OK" -ForegroundColor Green
    }
    Catch {
        Write-Host "  [X] UserRights: $_" -ForegroundColor Red
    }
}

Function Set-PowerShellSecurity {
    Write-Host "`n[+] Segurança do PowerShell…" -ForegroundColor Cyan
    Try {
        # ExecutionPolicy via registro
        New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell' `
            -Name 'ExecutionPolicy' -Value 'Restricted' -PropertyType String -Force | Out-Null
        Write-Host "  [√] ExecPolicy Restricted" -ForegroundColor Green
    }
    Catch {
        Write-Host "  [X] ExecPolicy: $_" -ForegroundColor Red
    }
}

Function Set-AdvancedSecuritySettings {
    Write-Host "`n[+] Segurança Avançada SMB e Network…" -ForegroundColor Cyan
    Try {
        Set-SmbServerConfiguration -EncryptData $true -RejectUnencryptedAccess $true -Force | Out-Null
        Write-Host "  [√] SMB Encryption ON" -ForegroundColor Green
    }
    Catch {
        Write-Host "  [X] SMB Config: $_" -ForegroundColor Red
    }
}

Function Set-ScheduledTasks {
    Write-Host "`n[+] Desabilitando ScheduledTasks…" -ForegroundColor Cyan
    $tasks = @{
        '\Microsoft\Windows\Application Experience\'                  = @('Microsoft Compatibility Appraiser', 'ProgramDataUpdater')
        '\Microsoft\Windows\Customer Experience Improvement Program\' = @('Consolidator', 'UsbCeip')
        '\Microsoft\Windows\DiskDiagnostic\'                          = @('Microsoft-Windows-DiskDiagnosticDataCollector')
    }
    foreach ($path in $tasks.Keys) {
        foreach ($name in $tasks[$path]) {
            Try {
                Disable-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction Stop
                Write-Host "  [√] Task $path\$name disabled" -ForegroundColor Green
            }
            Catch {
                Write-Host "  [X] Task $path\$($name): $_" -ForegroundColor Red
            }
        }
    }
}


Function Set-ExploitProtection {
    Write-Host "`n[+] Configurando ExploitProtection…" -ForegroundColor Cyan
    Try {
        Set-ProcessMitigation -System -Enable DEP, SEHOP, TerminateOnError -Force | Out-Null
        Set-ProcessMitigation -System -Enable CFG, StrictHandle -Force | Out-Null
        Write-Host "  [√] ExploitProtection System" -ForegroundColor Green
    }
    Catch {
        Write-Host "  [X] ExploitProtection: $_" -ForegroundColor Red
    }
}

Function Set-LoggingSettings {
    Write-Host "`n[+] Configurando Event Log…" -ForegroundColor Cyan
    $logs = @(
        @{Name = 'Application'; MaximumSizeInBytes = 100MB; OverflowAction = 'OverwriteAsNeeded' },
        @{Name = 'System'; MaximumSizeInBytes = 100MB; OverflowAction = 'OverwriteAsNeeded' },
        @{Name = 'Security'; MaximumSizeInBytes = 200MB; OverflowAction = 'DoNotOverwrite' },
        @{Name = 'Windows PowerShell'; MaximumSizeInBytes = 50MB; OverflowAction = 'OverwriteAsNeeded' }
    )
    foreach ($l in $logs) {
        Try {
            Limit-EventLog -LogName $l.Name -MaximumSize $l.MaximumSizeInBytes -OverflowAction $l.OverflowAction
            Write-Host "  [√] Log $($l.Name) set to $($l.MaximumSizeInBytes/1MB)MB" -ForegroundColor Green
        }
        Catch {
            Write-Host "  [X] Log $($l.Name): $_" -ForegroundColor Red
        }
    }
}

Function Set-AdditionalSecurity {
    Write-Host "`n[+] Configurações Adicionais…" -ForegroundColor Cyan
    Try {
        # AutoRun off
        New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' `
            -Name 'NoDriveTypeAutoRun' -Value 255 -PropertyType DWord -Force | Out-Null
        Write-Host "  [√] AutoRun disabled" -ForegroundColor Green
    }
    Catch {
        Write-Host "  [X] AdditionalSecurity: $_" -ForegroundColor Red
    }
}

Function Set-FinalChecks {
    Write-Host "`n[+] Verificações Finais…" -ForegroundColor Cyan
    Try {
        $cs = Get-CimInstance Win32_ComputerSystem
        Write-Host "  DomainJoined: $($cs.PartOfDomain)" -ForegroundColor ($cs.PartOfDomain?'Green':'Yellow')
        $fw = Get-NetFirewallProfile | Where-Object { $_.Enabled -eq $false }
        if ($fw) { Write-Host "  [X] Firewall OFF em: $($fw.Name -join ', ')" -ForegroundColor Red }
        else { Write-Host "  [√] Firewall ON todos profiles" -ForegroundColor Green }

        if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
            $md = Get-MpComputerStatus
            if ($md.AntivirusEnabled) { Write-Host "  [√] Defender OK" -ForegroundColor Green }
            else { Write-Host "  [X] Defender OFF" -ForegroundColor Red }
        }

        $u = New-Object -ComObject Microsoft.Update.Session
        $s = $u.CreateUpdateSearcher().Search("IsInstalled=0")
        Write-Host "  Updates pendentes: $($s.Updates.Count)" -ForegroundColor ($s.Updates.Count? 'Yellow':'Green')

        $rebootPend = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        Write-Host "  RebootPending: $rebootPend" -ForegroundColor ($($rebootPend)?'Yellow':'Green')
    }
    Catch {
        Write-Host "  [X] FinalChecks: $_" -ForegroundColor Red
    }
}
#endregion

#region EXECUÇÃO PRINCIPAL
Clear-Host
$startTime = Get-Date
Write-Host "`n=== HARDENING PARA WINDOWS SERVER 2025 ===" -ForegroundColor Cyan
Write-Host "=== Versão 2.1 | Início: $startTime ===`n" -ForegroundColor Cyan

Assert-Admin
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
Set-LoggingSettings
Set-AdditionalSecurity
Enable-BitLocker
Set-FinalChecks

Write-Host "`n=== HARDENING COMPLETO em $((Get-Date)-$startTime) ===" -ForegroundColor Green
if (-not $SkipReboot) {
    $r = Read-Host "Deseja REINICIAR agora? (S/N)"
    if ($r -match '^[sS]') {
        Write-Host "Reiniciando..." -ForegroundColor Yellow
        Restart-Computer -Force
    }
}
else {
    Write-Host "`n[!] Execute reboot para aplicar tudo" -ForegroundColor Yellow
}