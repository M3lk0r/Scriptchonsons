<#
.SYNOPSIS
    Captura e registra eventos de criação de usuários no Active Directory.

.DESCRIPTION
    O script coleta eventos de criação de usuários em todos os Controladores de Domínio (DCs),
    registra os detalhes em um log e exporta os resultados para um arquivo CSV.

.PARAMETER TimeUnit
    Unidade de tempo para buscar eventos (H para horas, D para dias, M para meses).

.PARAMETER TimeValue
    Valor numérico correspondente à unidade de tempo.

.EXAMPLE
    .\GetADUserCreationLogger.ps1 -TimeUnit D -TimeValue 7
    # Busca eventos dos últimos 7 dias

.NOTES
    Autor: Eduardo Augusto Gomes (eduardo.agms@outlook.com.br)
    Data: 04/02/2025
    Versão: 2.1
        - Suporte otimizado para PowerShell 7.5
        - Melhor tratamento de erros
        - Aprimoramento no logging
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Unidade de tempo: H (horas), D (dias) ou M (meses)")]
    [ValidateSet("H", "D", "M")]
    [string]$TimeUnit,

    [Parameter(Mandatory = $true, HelpMessage = "Quantidade de tempo para busca de eventos")]
    [ValidateRange(1, 365)]
    [int]$TimeValue
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$exportDir = "C:\export"
$logFile = "C:\logs\ADUserCreation.log"

foreach ($dir in @($exportDir, (Split-Path -Path $logFile))) {
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

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
        }[$Level] ?? "White"

        Write-Output $logEntry | Write-Host -ForegroundColor $color
    }
    catch {
        Write-Host "Erro ao escrever no log: $($_.Exception.Message)" -ForegroundColor Red
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

try {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Log "Este script requer PowerShell 7.0 ou superior. Versão atual: $($PSVersionTable.PSVersion)" -Level "ERROR"
        exit 1
    }
    
    switch ($TimeUnit) {
        "H" { $Time = (Get-Date).AddHours(-$TimeValue) }
        "D" { $Time = (Get-Date).AddDays(-$TimeValue) }
        "M" { $Time = (Get-Date).AddMonths(-$TimeValue) }
    }

    $Report = [System.Collections.Generic.List[PSCustomObject]]::new()
    $AllDCs = Get-ADDomainController -Filter *
    $filename = Get-Date -Format "yyyy.MM.dd"
    $exportcsv = "$exportDir\ad_users_creators_$($filename).csv"

    Import-ADModule

    ForEach ($DC in $AllDCs) {
        try {
            Write-Log "Coletando eventos do DC: $($DC.Name)"
            Get-WinEvent -ComputerName $DC.Name -FilterHashtable @{LogName = "Security"; ID = 4720; StartTime = $Time } -ErrorAction SilentlyContinue | ForEach-Object {
                $event = [xml]$_.ToXml()
                if ($event) {
                    $objReport = [PSCustomObject]@{
                        User         = $event.Event.EventData.Data[0]."#text"
                        Creator      = $event.Event.EventData.Data[4]."#text"
                        DC           = $event.Event.System.Computer
                        CreationDate = $_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                    }
                    $Report.Add($objReport)
                }
            }
        }
        catch {
            Write-Log "Erro ao coletar eventos do DC $($DC.Name): $($_.Exception.Message)" -Level "ERROR"
        }
    }

    if ($Report.Count -gt 0) {
        $Report | Export-Csv -Path $exportcsv -NoTypeInformation -Delimiter "," -Encoding UTF8
        Write-Log "Relatório exportado para: $exportcsv"
    }
    else {
        Write-Log "Nenhum evento de criação de usuário encontrado no período especificado." -Level "WARNING"
    }
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}