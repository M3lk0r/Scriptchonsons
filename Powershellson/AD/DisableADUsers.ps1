<#
.SYNOPSIS
    Desabilita usuários no Active Directory a partir de um arquivo CSV.

.DESCRIPTION
    Este script importa dados de usuários a partir de um arquivo CSV, onde cada linha contém o `sAMAccountName` de cada usuário no Active Directory.
    O script desabilita os usuários cujos `sAMAccountName` estão presentes no arquivo CSV.
    O script suporta caracteres especiais através da codificação UTF-8.

.PARAMETER CsvPath
    O caminho completo para o arquivo CSV que contém os `sAMAccountName` dos usuários a serem desabilitados.
    Exemplo: "C:\csv\users2disable.csv"

.PARAMETER Delimiter
    O delimitador utilizado no arquivo CSV. O padrão é ";" para arquivos CSV com dados separados por ponto e vírgula.

.PARAMETER Encoding
    A codificação do arquivo CSV. Por padrão, é definido como "UTF8" para suportar caracteres especiais.

.EXAMPLE
    .\DisableADUsers.ps1 -CsvPath "C:\csv\users2disable.csv" -Delimiter ";" -Encoding "UTF8"

.NOTES
    Autor: Eduardo Augusto Gomes(eduardo.agms@outlook.com.br)
    Data: 29/01/2025
    Versão: 1.3
        - Melhorias na modularização e suporte ao -WhatIf.
    
.LINK
    Repositório: https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Caminho completo para o arquivo CSV com os sAMAccountName dos usuários a serem desabilitados.")]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$CsvPath,

    [Parameter(Mandatory = $false, HelpMessage = "Delimitação do CSV (, ou ;), padrão é (;).")]
    [string]$Delimiter = ";",

    [Parameter(Mandatory = $false, HelpMessage = "Codificação do arquivo CSV, padrão é UTF8.")]
    [string]$Encoding = "UTF8"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$logFile = "C:\logs\DisableADUsers.log"

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

function Import-ADModule {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        Write-Log "Módulo ActiveDirectory importado com sucesso."
    }
    catch {
        Write-Log "Falha ao importar o módulo ActiveDirectory: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

function Disable-ADUserAccount {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$SamAccountName
    )
    try {
        $user = Get-ADUser -Identity $SamAccountName -Properties Enabled -ErrorAction Stop

        if ($user.Enabled -eq $true) {
            if ($PSCmdlet.ShouldProcess($SamAccountName, "Desabilitar conta de usuário")) {
                Disable-ADAccount -Identity $user -Confirm:$false
                Write-Log "Usuário $($SamAccountName) desabilitado com sucesso."
            }
        }
        else {
            Write-Log "Usuário $($SamAccountName) já está desabilitado." -Level "WARNING"
        }
    }
    catch {
        Write-Log "Erro ao tentar desabilitar o usuário $($SamAccountName): $($_.Exception.Message)" -Level "ERROR"
    }
}

function Initialize-UsersFromCSV {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$CsvPath,
        [string]$Delimiter,
        [string]$Encoding
    )

    try {
        $usuarios = Import-Csv -Path $CsvPath -Delimiter $Delimiter -Encoding $Encoding
        Write-Log "CSV importado com sucesso. Total de usuários a processar: $($usuarios.Count)"

        $totalUsuarios = $usuarios.Count
        $counter = 0

        foreach ($usuario in $usuarios) {
            $counter++
            $progress = [math]::Round(($counter / $totalUsuarios) * 100, 2)
            Write-Progress -Activity "Desabilitando usuários" -Status "Progresso: $progress%" -PercentComplete $progress

            if ($usuario.sAMAccountName) {
                Disable-ADUserAccount -SamAccountName $usuario.sAMAccountName
            }
            else {
                Write-Log "Linha $counter do CSV não contém um valor válido para sAMAccountName." -Level "WARNING"
            }
        }
    }
    catch {
        Write-Log "Falha ao importar o CSV: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

try {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Log "Este script requer PowerShell 7.0 ou superior. Versão atual: $($PSVersionTable.PSVersion)" -Level "ERROR"
        exit 1
    }
    
    Import-ADModule
    Initialize-UsersFromCSV -CsvPath $CsvPath -Delimiter $Delimiter -Encoding $Encoding
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}