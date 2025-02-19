<#
.SYNOPSIS
    Cria escopos e reservas DHCP automaticamente a partir de um arquivo JSON de configuração.

.DESCRIPTION
    Este script importa um arquivo JSON contendo a configuração de escopos e reservas DHCP e aplica as definições em um servidor DHCP especificado.
    Ele verifica se os escopos já existem antes de criá-los e adiciona reservas conforme necessário.
    O script inclui logging detalhado, tratamento de erros e feedback visual durante a execução.

.PARAMETER ConfigFile
    Caminho completo para o arquivo JSON contendo as configurações de escopos e reservas DHCP.
    Exemplo: "C:\config\dhcp_config.json"

.PARAMETER ServerName
    FQDN ou nome do servidor DHCP onde os escopos e reservas serão configurados.
    Exemplo: "dhcpserver.contoso.com"

.EXAMPLE
    .\ConfigureDHCP.ps1 -ConfigFile "C:\config\dhcp_config.json" -ServerName "dhcpserver.contoso.com"

.NOTES
    Autor: Eduardo Augusto Gomes (eduardo.agms@outlook.com.br)
    Data: 06/02/2025
    Versão: 1.1
        - Removido o uso de ForEach-Object -Parallel.
        - Melhorias na modularização e suporte ao -WhatIf.

.LINK
    Repositório: https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Caminho completo para o arquivo JSON de configuração.")]
    [string]$ConfigFile,
    [Parameter(Mandatory = $true, HelpMessage = "FQDN do servidor DHCP.")]
    [string]$ServerName
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$logFile = "C:\logs\NewDHCPScopes.log"

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    try {
        $dataHora = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$dataHora] [$Level] $Message"

        $logDir = [System.IO.Path]::GetDirectoryName($LogFile)
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        $logEntry | Out-File -FilePath $LogFile -Encoding UTF8 -Append

        $color = @{
            "INFO"    = "Green"
            "ERROR"   = "Red"
            "WARNING" = "Yellow"
        }
        $logColor = $color[$Level]
        Write-Output $logEntry | Write-Host -ForegroundColor $logColor
    }
    catch {
        Write-Host "Erro ao escrever no log: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Get-PSVersion {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Log "Este script requer PowerShell 7.0 ou superior. Versão atual: $($PSVersionTable.PSVersion)" -Level "ERROR"
        exit 1
    }
}

function Import-DhcpServer {
    try {
        Import-Module DhcpServer -ErrorAction Stop
        Write-Log "Módulo DhcpServer importado com sucesso."
    }
    catch {
        Write-Log "Falha ao importar o módulo DhcpServer: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

function Import-DHCPConfig {
    param (
        [string]$FilePath
    )
    if (Test-Path $FilePath) {
        return Get-Content -Path $FilePath | ConvertFrom-Json
    }
    else {
        Write-Log "Arquivo de configuração não encontrado: $FilePath" -Level "ERROR"
        exit 1
    }
}

function Convert-ToMacFormat {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MacAddress
    )

    $macRegex = "^[0-9A-Fa-f]{2}([-:])(?:[0-9A-Fa-f]{2}\1){4}[0-9A-Fa-f]{2}$"

    if ($MacAddress -match $macRegex) {
        $cleanMac = $MacAddress -replace "[-:]", ""
        $formattedMac = ($cleanMac.ToUpper() -split '(?<=\G..)(?=.)') -join '-'
        return $formattedMac
    }
    else {
        Write-Log "Endereço MAC inválido: $MacAddress" -Level "ERROR"
        return $null
    }
}

function New-DHCPScope {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$ServerName,
        [string]$ScopeName,
        [string]$StartRange,
        [string]$EndRange,
        [string]$SubnetMask,
        [string]$Gateway,
        [System.Object]$DNSServers,
        [string]$LeaseTime
    )

    if ($PSCmdlet.ShouldProcess("Criar escopo DHCP $ScopeName em $ServerName", "Adicionar escopo")) {
        try {
            $existingScope = Get-DhcpServerv4Scope -ComputerName $ServerName | Where-Object { $_.Name -eq $ScopeName }
            if ($existingScope) {
                Write-Log "Escopo $ScopeName já existe. Pulando..." -Level "WARNING"
            }
            else {
                Add-DhcpServerv4Scope `
                    -ComputerName $ServerName `
                    -Name $ScopeName `
                    -StartRange $StartRange `
                    -EndRange $EndRange `
                    -SubnetMask $SubnetMask `
                    -State Active `
                    -ErrorAction Stop

                Set-DhcpServerv4OptionValue `
                    -ComputerName $ServerName `
                    -ScopeId $StartRange `
                    -Router $Gateway `
                    -DnsServer $DNSServers `
                    -ErrorAction Stop

                Write-Log "Escopo $ScopeName criado com sucesso."
            }
        }
        catch {
            Write-Log "Erro ao criar o escopo: $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

function Add-DHCPReservation {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$ServerName,
        [string]$IPAddress,
        [string]$MACAddress,
        [string]$Description,
        [string]$ScopeID
    )

    $ClientID = Convert-ToMacFormat -MacAddress $MACAddress

    if ($PSCmdlet.ShouldProcess("Adicionar reserva para $IPAddress ($MACAddress) em $ServerName", "Criar reserva")) {
        try {
            $existingReservation = Get-DhcpServerv4Reservation `
                -ComputerName $ServerName `
                -ScopeId $ScopeID `
                -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -eq $IPAddress }
            if ($existingReservation) {
                Write-Log "Reserva para $IPAddress já existe. Pulando..." -Level "WARNING"
            }
            else {
                Add-DhcpServerv4Reservation `
                    -ComputerName $ServerName `
                    -ScopeId $ScopeID `
                    -IPAddress $IPAddress `
                    -ClientId $ClientID `
                    -Description $Description `
                    -ErrorAction Stop 
                Write-Log "Reserva adicionada: $IPAddress ($MACAddress)"
            }
        }
        catch {
            Write-Log "Erro ao adicionar reserva: $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

function Enter-DHCPConfig {
    param (
        [string]$ServerName,
        [object]$Config
    )

    foreach ($scope in $config.Scopes) {
        New-DHCPScope `
            -ServerName $ServerName `
            -ScopeName $scope.Name `
            -StartRange $scope.StartRange `
            -EndRange $scope.EndRange `
            -SubnetMask $scope.SubnetMask `
            -Gateway $scope.Gateway `
            -DNSServers $scope.DNSServers `
            -LeaseTime $scope.LeaseTime
    }

    foreach ($reservation in $config.Reservations) {
        Add-DHCPReservation `
            -ServerName $ServerName `
            -IPAddress $reservation.IPAddress `
            -MACAddress $reservation.MACAddress `
            -Description $reservation.Description `
            -ScopeID $reservation.ScopeID
    }
}

try {
    Write-Log "Iniciando script."

    Get-PSVersion

    Import-DhcpServer

    $config = Import-DHCPConfig -FilePath $ConfigFile

    Enter-DHCPConfig -ServerName $ServerName -Config $config

    Write-Log "Configuração do DHCP aplicada com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}