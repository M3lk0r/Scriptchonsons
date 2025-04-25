<#
.SYNOPSIS
  Aplica regras de firewall inbound/outbound seguindo princípio mínimo privilégio.
.DESCRIPTION
  Cria perfis Domain, Private e Public, permitindo somente o que for necessário.
#>

param(
    # Exemplo de portas e serviços permitidos
    [int[]]$InboundTCPAllowedPorts  = @(80,443,3389),
    [string[]]$InboundAllowedPrograms = @(
        'C:\Windows\System32\svchost.exe',  # serviços Windows essenciais
        #'C:\Program Files\MyApp\MySvc.exe' # exemplo app
    )
)

Function Assert-Admin {
    If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "É necessário rodar como Administrador!"
        Exit 1
    }
}

Function Reset-Firewall {
    Write-Host "Resetando firewall para estado padrão…" -ForegroundColor Cyan
    netsh advfirewall reset
}

Function Set-DefaultPolicies {
    Write-Host "Setando política padrão (bloqueia in e out por default)…" -ForegroundColor Cyan
    netsh advfirewall set allprofiles firewallpolicy blockinbound,blockoutbound
}

Function Enable-RequiredInbound {
    Write-Host "Criando regras inbound essenciais…" -ForegroundColor Cyan
    foreach ($p in $InboundTCPAllowedPorts) {
        New-NetFirewallRule -DisplayName "HW_In_TCP_$p" -Direction Inbound -Protocol TCP -LocalPort $p `
          -Action Allow -Profile Domain,Private -EdgeTraversalPolicy Disabled
    }
    foreach ($exe in $InboundAllowedPrograms) {
        $name = Split-Path $exe -Leaf
        New-NetFirewallRule -DisplayName "HW_In_Program_$name" -Direction Inbound -Program $exe `
          -Action Allow -Profile Domain,Private
    }
}

Function Enable-DomainOutbound {
    Write-Host "Permitindo tráfego outbound para DNS, NTP, AD, WSUS…" -ForegroundColor Cyan
    # DNS
    New-NetFirewallRule -DisplayName "HW_Out_DNS" -Direction Outbound -Protocol UDP -RemotePort 53 `
        -Action Allow -Profile Domain,Private
    # NTP
    New-NetFirewallRule -DisplayName "HW_Out_NTP" -Direction Outbound -Protocol UDP -RemotePort 123 `
        -Action Allow -Profile Domain,Private
    # LDAP / Kerberos / RPC (para DC)
    New-NetFirewallRule -DisplayName "HW_Out_LDAP"   -Direction Outbound -Protocol TCP -RemotePort 389,636 -Action Allow -Profile Domain
    New-NetFirewallRule -DisplayName "HW_Out_KRB5"   -Direction Outbound -Protocol TCP -RemotePort 88    -Action Allow -Profile Domain
    New-NetFirewallRule -DisplayName "HW_Out_RPC"    -Direction Outbound -Protocol TCP -RemotePort 135   -Action Allow -Profile Domain
    New-NetFirewallRule -DisplayName "HW_Out_SecSvc" -Direction Outbound -Protocol TCP -RemotePort 445   -Action Allow -Profile Domain
    # WSUS
    New-NetFirewallRule -DisplayName "HW_Out_WSUS" -Direction Outbound -Protocol TCP -RemotePort 8530,8531 `
        -Action Allow -Profile Domain,Private
}

# --------------------------------------------------
# Execução
# --------------------------------------------------
Assert-Admin
Reset-Firewall
Set-DefaultPolicies
Enable-RequiredInbound
Enable-DomainOutbound

Write-Host "`n*** Regras de firewall aplicadas com sucesso. ***" -ForegroundColor Green