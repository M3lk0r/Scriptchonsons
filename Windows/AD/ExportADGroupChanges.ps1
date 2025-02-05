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
    .\ExportADGroupChanges.ps1 -TimeUnit "H" -TimeValue 24 -OutputDir "C:\export"

.NOTES
    Autor: Eduardo Augusto Gomes (eduardo.agms@outlook.com.br)
    Data: 05/02/2025
    Versão: 3.1
        - Adicionado suporte a unidades de tempo (horas, dias, meses)
        - Suporte a -WhatIf e -Confirm
        - Otimização para PowerShell 7.5

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

    [Parameter(Mandatory = $false, HelpMessage = "Diretorio para salvar relatorio")]
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

function Get-ADGroupChanges {
    param (
        [int]$EventID,
        [string]$Action,
        [string]$TimeUnit,
        [int]$TimeValue
    )
    
    $Results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $StartTime = switch ($TimeUnit) {
        "H" { (Get-Date).AddHours(-$TimeValue) }
        "D" { (Get-Date).AddDays(-$TimeValue) }
        "M" { (Get-Date).AddMonths(-$TimeValue) }
    }
    
    $DCs = Get-ADDomainController -Filter *

    $Results += $DCs | ForEach-Object -Parallel {
        $DC = $_
        $LocalResults = [System.Collections.Generic.List[PSCustomObject]]::new()
        try {
            $Events = Get-WinEvent -ComputerName $DC.Name -FilterHashtable @{LogName = "Security"; ID = $using:EventID; StartTime = $using:StartTime } -ErrorAction Stop
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
            Write-Host "Eventos de $using:Action capturados com sucesso em $($DC.Name)"
        }
        catch {
            Write-Host "Erro ao capturar eventos de $using:Action em $($DC.Name): $($_.Exception.Message)" -ForegroundColor Red
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
    
    Import-ADModule

    if ($PSCmdlet.ShouldProcess("Exportar eventos de alterações de grupos do AD", "Confirma a execução do script?")) {
        $AdditionsReport = Get-ADGroupChanges -EventID 4732 -Action "Added"
        $RemovalsReport = Get-ADGroupChanges -EventID 4733 -Action "Removed"

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