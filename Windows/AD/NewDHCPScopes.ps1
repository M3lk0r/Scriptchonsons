[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Caminho completo para o arquivo JSON de configuração.")]
    [string]$ConfigFile
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

function New-DHCPScope {
    param (
        [string]$ScopeName,
        [string]$StartRange,
        [string]$EndRange,
        [string]$SubnetMask,
        [string]$Gateway,
        [string]$DNSServers,
        [string]$LeaseTime
    )
    try {
        $existingScope = Get-DhcpServerv4Scope | Where-Object { $_.Name -eq $ScopeName }
        if ($existingScope) {
            Write-Log "Escopo $ScopeName já existe. Pulando..." -Level "WARNING"
        }
        else {
            Add-DhcpServerv4Scope -Name $ScopeName -StartRange $StartRange -EndRange $EndRange -SubnetMask $SubnetMask -State Active
            Set-DhcpServerv4OptionValue -ScopeId $StartRange -Router $Gateway -DnsServer $DNSServers
            Write-Log "Escopo $ScopeName criado com sucesso."
        }
    }
    catch {
        Write-Log "Erro ao criar o escopo: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Add-DHCPReservation {
    param (
        [string]$IPAddress,
        [string]$MACAddress,
        [string]$Description,
        [string]$ScopeID
    )
    try {
        $existingReservation = Get-DhcpServerv4Reservation -ScopeId $ScopeID -ComputerName $env:COMPUTERNAME -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -eq $IPAddress }
        if ($existingReservation) {
            Write-Log "Reserva para $IPAddress já existe. Pulando..." -Level "WARNING"
        }
        else {
            Add-DhcpServerv4Reservation -ScopeId $ScopeID -IPAddress $IPAddress -ClientId $MACAddress -Description $Description
            Write-Log "Reserva adicionada: $IPAddress ($MACAddress)"
        }
    }
    catch {
        Write-Log "Erro ao adicionar reserva: $($_.Exception.Message)" -Level "ERROR"
    }
}

try {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Log "Este script requer PowerShell 7.0 ou superior. Versão atual: $($PSVersionTable.PSVersion)" -Level "ERROR"
        exit 1
    }
    $config = Import-DHCPConfig -FilePath $ConfigFile

    foreach ($scope in $config.Scopes) {
        New-DHCPScope -ScopeName $scope.Name -StartRange $scope.StartRange -EndRange $scope.EndRange -SubnetMask $scope.SubnetMask -Gateway $scope.Gateway -DNSServers ($scope.DNSServers -join ",") -LeaseTime $scope.LeaseTime
    }

    foreach ($reservation in $config.Reservations) {
        Add-DHCPReservation -IPAddress $reservation.IPAddress -MACAddress $reservation.MACAddress -Description $reservation.Description -ScopeID $reservation.ScopeID
    }

    Write-Log "Configuração do DHCP aplicada com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}