<#
.SYNOPSIS
    Registra informações de logon do usuário, incluindo detalhes da máquina, em um arquivo CSV.

.DESCRIPTION
    Este script coleta informações como nome de usuário, nome do computador, endereços IP (Ethernet e Wi-Fi), modelo do computador, número de série, horário de boot e horário de logon.
    Os dados são salvos em um arquivo CSV no diretório especificado. O script também inclui tratamento de erros, logging e suporte ao -WhatIf.

.PARAMETER LogDirectory
    Diretório onde o arquivo CSV será salvo. O padrão é "\\server\User_logs\Events".

.PARAMETER WhatIf
    Simula a execução do script sem realmente criar ou modificar arquivos.

.EXAMPLE
    .\LogonLogging.ps1 -LogDirectory "\\server\User_logs\Events"

.NOTES
    Autor: Eduardo Augusto Gomes(eduardo.agms@outlook.com.br)
    Data: 06/02/2025
    Versão: 1.2
        - Corrigido erro de ShouldProcess na função Save-LogonLog.
        - Adicionado tratamento de erros e logging.
        - Suporte ao -WhatIf.
        - Modularização do código.

.LINK
    https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Diretório onde o arquivo CSV será salvo.")]
    [string]$LogDirectory = "\\server\User_logs\Events"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$logFile = "C:\logs\LogonLogging.log"

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$Level] $Message"

        $logDir = [System.IO.Path]::GetDirectoryName($logFile)
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        $logEntry | Out-File -FilePath $logFile -Encoding UTF8 -Append

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

function Get-NetworkInfo {
    try {
        $Ethernet = Get-NetIpAddress | Where-Object {($_.InterfaceAlias -eq "Ethernet") -and ($_.AddressFamily -eq "IPv4")} | ForEach-Object { $_.IPAddress }
        $WiFi = Get-NetIpAddress | Where-Object {($_.InterfaceAlias -eq "Wi-Fi") -and ($_.AddressFamily -eq "IPv4")} | ForEach-Object { $_.IPAddress }
        Write-Log "Informações de rede obtidas com sucesso."
        return $Ethernet, $WiFi
    }
    catch {
        Write-Log "Falha ao obter informações de rede: $($_.Exception.Message)" -Level "ERROR"
        return $null, $null
    }
}

function Get-SystemInfo {
    try {
        $computermodel = Get-WmiObject Win32_ComputerSystem | ForEach-Object { $_.Model }
        $serial = Get-WmiObject Win32_Bios | ForEach-Object { $_.SerialNumber }
        $boottime = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime
        Write-Log "Informações do sistema obtidas com sucesso."
        return $computermodel, $serial, $boottime
    }
    catch {
        Write-Log "Falha ao obter informações do sistema: $($_.Exception.Message)" -Level "ERROR"
        return $null, $null, $null
    }
}

function Get-LogonTable {
    param (
        [string]$time,
        [string]$username,
        [string]$computername,
        [string]$Ethernet,
        [string]$WiFi,
        [string]$computermodel,
        [string]$serial,
        [string]$action,
        [string]$boottime
    )

    try {
        $table = [PSCustomObject]@{
            'Date/Time'   = $time
            'Username'    = $username
            'ComputerName' = $computername
            'Ethernet'    = $Ethernet
            'WiFi'        = $WiFi
            'Model'       = $computermodel
            'Serial'      = $serial
            'Action'      = $action
            'Boot Time'   = $boottime
        } | Select-Object 'Date/Time', 'Username', 'ComputerName', 'Ethernet', 'WiFi', 'Model', 'Serial', 'Action', 'Boot Time'

        Write-Log "Tabela de logon criada com sucesso."
        return $table
    }
    catch {
        Write-Log "Falha ao criar tabela de logon: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Save-LogonLog {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [string]$directory,
        [string]$file,
        [object]$table
    )

    try {
        if ($PSCmdlet.ShouldProcess($file, "Salvar log de logon")) {
            if (Test-Path "$directory\$file") {
                $table | Export-Csv -NoTypeInformation -Append -Path "$directory\$file"
                Write-Log "Log de logon adicionado ao arquivo existente: $directory\$file"
            }
            else {
                $table | Export-Csv -NoTypeInformation -Path "$directory\$file"
                Write-Log "Novo arquivo de log de logon criado: $directory\$file"
            }
        }
    }
    catch {
        Write-Log "Falha ao salvar log de logon: $($_.Exception.Message)" -Level "ERROR"
    }
}

try {
    Write-Log "Iniciando script de registro de logon."

    $username = $env:USERNAME
    $computername = $env:COMPUTERNAME
    $timeformat = 'MM-dd-yyyy hh:mm:ss tt'
    $time = (Get-Date).ToString($timeformat)
    $action = 'Logon'

    $Ethernet, $WiFi = Get-NetworkInfo
    $computermodel, $serial, $boottime = Get-SystemInfo

    $table = Get-LogonTable -time $time -username $username -computername $computername -Ethernet $Ethernet -WiFi $WiFi -computermodel $computermodel -serial $serial -action $action -boottime $boottime

    if ($table) {
        $filename = 'Logon-' + $(((Get-Date)).ToString("yyyyMMdd")) + '.csv'
        $file = $filename

        Save-LogonLog -directory $LogDirectory -file $file -table $table
    }

    Write-Log "Script concluído com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}