<#
.SYNOPSIS
    Exporta eventos de adição e remoção de usuários em grupos do Active Directory.

.DESCRIPTION
    Este script coleta eventos de log do Active Directory para registrar mudanças na associação de grupos.
    Ele consulta os controladores de domínio e gera um relatório CSV.

.PARAMETER TimeUnit
    Unidade de tempo para a busca de eventos: H (horas), D (dias) ou M (meses).

.PARAMETER TimeValue
    Quantidade de tempo para a busca de eventos. Deve ser um valor entre 1 e 365.

.PARAMETER OutputDir
    Caminho do diretório onde o relatório CSV será salvo.
    Exemplo: "C:\export"

.EXAMPLE
    .\Export-ADGroupChanges.ps1 -TimeUnit "H" -TimeValue 24 -OutputDir "C:\export"

.NOTES
    Autor: Eduardo Augusto Gomes (eduardo.agms@outlook.com.br)
    Data: 05/02/2025
    Versão: 3.3
        - Adicionada verificação de disponibilidade do namespace System.Diagnostics.Eventing.Reader.
        - Documentação clara dos pré-requisitos.

.PREREQUISITES
    - PowerShell 7.0 ou superior.
    - Módulo ActiveDirectory instalado e importado.
    - Acesso aos logs de segurança nos controladores de domínio.
    - Namespace System.Diagnostics.Eventing.Reader disponível (presente no .NET Framework ou .NET Core 3.1+).

.LINK
    Repositório: https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Unidade de tempo: H (horas), D (dias) ou M (meses)")]
    [ValidateSet("H", "D", "M")]
    [string]$TimeUnit,

    [Parameter(Mandatory = $true, HelpMessage = "Quantidade de tempo para busca de eventos")]
    [ValidateRange(1, 365)]
    [int]$TimeValue,

    [Parameter(Mandatory = $false, HelpMessage = "Diretório para salvar relatório")]
    [string]$OutputDir = "C:\export"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$logFile = "C:\logs\GroupsChange.log"

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    try {
        $dataHora = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$dataHora] [$Level] $Message"

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
        Write-Host "Erro ao escrever no log: $_" -ForegroundColor Red
        exit 1
    }
}

function Import-ADModule {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        Write-Log "Módulo ActiveDirectory importado com sucesso."
    }
    catch {
        Write-Log "Erro ao importar o módulo ActiveDirectory: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

function Test-EventingReaderAvailable {
    try {
        $null = [System.Diagnostics.Eventing.Reader.EventLogProviderException]
        return $true
    }
    catch {
        return $false
    }
}

function Get-ADGroupChanges {
    param (
        [int]$EventID,
        [string]$Action,
        [datetime]$StartTime
    )
    
    $Results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $DCs = Get-ADDomainController -Filter *

    $Results += $DCs | ForEach-Object -Parallel {
        $DC = $_
        $LocalResults = [System.Collections.Generic.List[PSCustomObject]]::new()
        try {
            $Events = Get-WinEvent -ComputerName $DC.Name -FilterHashtable @{
                LogName   = "Security"
                ID        = $using:EventID
                StartTime = $using:StartTime
            } -ErrorAction Stop

            if ($Events) {
                $Events | ForEach-Object {
                    $Event = $_
                    $EventXML = [xml]$Event.ToXml()
                    $LocalResults.Add([PSCustomObject]@{
                            Action    = $using:Action
                            DC        = $EventXML.Event.System.Computer
                            EventTime = $Event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                            Group     = $EventXML.Event.EventData.Data[2]."#text"
                            User      = $EventXML.Event.EventData.Data[0]."#text"
                            Admin     = $EventXML.Event.EventData.Data[6]."#text"
                        })
                }
                Write-Log "Eventos de $using:Action capturados com sucesso em $($DC.Name)" -Level "INFO"
            }
            else {
                Write-Log "Nenhum evento de $using:Action encontrado em $($DC.Name)." -Level "WARNING"
            }
        }
        catch [System.Diagnostics.Eventing.Reader.EventLogNotFoundException] {
            Write-Log "Log de segurança não encontrado em $($DC.Name)." -Level "ERROR"
        }
        catch [System.Diagnostics.Eventing.Reader.EventLogProviderException] {
            Write-Log "Erro ao acessar o log de segurança em $($DC.Name): $($_.Exception.Message)" -Level "ERROR"
        }
        catch {
            Write-Log "Erro ao capturar eventos de $using:Action em $($DC.Name): $($_.Exception.Message)" -Level "ERROR"
        }
        return $LocalResults
    }
    return $Results
}

try {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Log "Este script requer PowerShell 7.0 ou superior. Versão atual: $($PSVersionTable.PSVersion)" -Level "ERROR"
        exit 1
    }

    if (-not (Test-EventingReaderAvailable)) {
        Write-Log "O namespace System.Diagnostics.Eventing.Reader não está disponível neste ambiente. Certifique-se de que o .NET Framework ou .NET Core 3.1+ está instalado." -Level "ERROR"
        exit 1
    }

    Import-ADModule

    if ($PSCmdlet.ShouldProcess("Exportar eventos de alterações de grupos do AD", "Confirma a execução do script?")) {
        $StartTime = switch ($TimeUnit) {
            "H" { (Get-Date).AddHours(-$TimeValue) }
            "D" { (Get-Date).AddDays(-$TimeValue) }
            "M" { (Get-Date).AddMonths(-$TimeValue) }
        }

        $AdditionsReport = Get-ADGroupChanges -EventID 4732 -Action "Added" -StartTime $StartTime
        $RemovalsReport = Get-ADGroupChanges -EventID 4733 -Action "Removed" -StartTime $StartTime

        $CombinedReport = $AdditionsReport + $RemovalsReport
        $FileName = Join-Path -Path $OutputDir -ChildPath "ADGroupChanges_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').csv"
        try {
            if ($CombinedReport.Count -gt 0) {
                $CombinedReport | Export-Csv -Path $FileName -NoTypeInformation -Delimiter "," -WhatIf:$WhatIfPreference
                Write-Log "Relatório exportado para $FileName"
            }
            else {
                Write-Log "Nenhum evento encontrado para exportação." -Level "WARNING"
            }
        }
        catch {
            Write-Log "Erro ao exportar relatório: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    else {
        Write-Log "Operação cancelada pelo usuário." -Level "WARNING"
    }
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}