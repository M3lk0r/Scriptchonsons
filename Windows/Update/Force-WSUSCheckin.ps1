<#
.SYNOPSIS
    Força uma verificação de atualizações do WSUS em um computador remoto.

.DESCRIPTION
    Este script executa uma série de comandos para forçar uma verificação de atualizações do WSUS em um computador remoto.
    Ele reinicia o serviço do Windows Update, executa uma pesquisa de atualizações e força a detecção e o relatório de atualizações.

.PARAMETER Computer
    Nome do computador remoto onde a verificação de atualizações será forçada.

.PARAMETER WhatIf
    Simula a execução do script sem realmente executar os comandos.

.EXAMPLE
    .\Force-WSUSCheckin.ps1 -Computer "srvcmp001099"

.NOTES
    Autor: Eduardo Augusto Gomes(eduardo.agms@outlook.com.br)
    Data: 06/02/2025
    Versão: 1.1
        - Adicionado tratamento de erros e logging.
        - Suporte ao -WhatIf.
        - Modularização do código.

.LINK
    https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Nome do computador remoto onde a verificação de atualizações será forçada.")]
    [string]$Computer
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$logFile = "C:\logs\ForceWSUSCheckin.log"

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

function Start-WindowsUpdateService {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$Computer
    )

    try {
        if ($PSCmdlet.ShouldProcess($Computer, "Reiniciar o serviço do Windows Update")) {
            Invoke-Command -ComputerName $Computer -ScriptBlock {
                Start-Service wuauserv -Verbose
            }
            Write-Log "Serviço do Windows Update reiniciado com sucesso no computador $Computer."
        }
    }
    catch {
        Write-Log "Falha ao reiniciar o serviço do Windows Update no computador $($Computer): $($_.Exception.Message)" -Level "ERROR"
    }
}

function Search-WindowsUpdates {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$Computer
    )

    try {
        if ($PSCmdlet.ShouldProcess($Computer, "Executar pesquisa de atualizações")) {
            $Cmd = '$updateSession = new-object -com "Microsoft.Update.Session";$updates=$updateSession.CreateupdateSearcher().Search($criteria).Updates'
            & c:\bin\psexec.exe -s \\$Computer powershell.exe -command $Cmd
            Write-Log "Pesquisa de atualizações executada com sucesso no computador $Computer."
        }
    }
    catch {
        Write-Log "Falha ao executar pesquisa de atualizações no computador $($Computer): $($_.Exception.Message)" -Level "ERROR"
    }
}

function Force-WindowsUpdateDetection {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$Computer
    )

    try {
        if ($PSCmdlet.ShouldProcess($Computer, "Forçar detecção de atualizações")) {
            Invoke-Command -ComputerName $Computer -ScriptBlock {
                wuauclt /detectnow
                (New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()
                wuauclt /reportnow
                c:\windows\system32\UsoClient.exe startscan
            }
            Write-Log "Detecção de atualizações forçada com sucesso no computador $Computer."
        }
    }
    catch {
        Write-Log "Falha ao forçar detecção de atualizações no computador $($Computer): $($_.Exception.Message)" -Level "ERROR"
    }
}

try {
    Write-Log "Iniciando script de verificação de atualizações do WSUS no computador $Computer."

    Start-WindowsUpdateService -Computer $Computer

    Search-WindowsUpdates -Computer $Computer

    Write-Log "Aguardando 10 segundos para sincronização de atualizações."
    Start-Sleep -Seconds 10

    Force-WindowsUpdateDetection -Computer $Computer

    Write-Log "Script concluído com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}