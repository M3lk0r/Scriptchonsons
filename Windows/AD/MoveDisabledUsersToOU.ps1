<#
.SYNOPSIS
    Move contas de usuários desativadas para uma Unidade Organizacional (OU) específica no Active Directory.

.DESCRIPTION
    Este script localiza todos os usuários desativados no domínio e os move para uma OU especificada.
    O script suporta tratamento de erros, logging e feedback visual durante a execução.

.PARAMETER MoveToOU
    Caminho da Unidade Organizacional (OU) de destino para onde os usuários desativados serão movidos.

.EXAMPLE
    .\MoveDisabledUsersToOU.ps1 -MoveToOU "OU=Disabled Users,DC=domain,DC=com"

.NOTES
    Autor: Eduardo Augusto Gomes(eduardo.agms@outlook.com.br)
    Data: 29/01/2025
    Versão: 2.1
        - Melhorias na modularização e suporte ao -WhatIf.
        - Remoção de paralelismo e simplificação do código.

.LINK
    https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Caminho da Unidade Organizacional (OU) de destino para onde os usuários desativados serão movidos.")]
    [string]$MoveToOU
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$logFile = "C:\logs\MoveDisabledUsersToOU.log"

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

function Get-DisabledUsers {
    try {
        $disabledUsers = Get-ADUser -Filter { Enabled -eq $false } -Properties DistinguishedName -ErrorAction Stop
        Write-Log "Usuários desativados obtidos com sucesso. Total de usuários: $($disabledUsers.Count)"
        return $disabledUsers
    }
    catch {
        Write-Log "Falha ao obter usuários desativados: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Move-DisabledUsersToOU {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$TargetOU,
        [array]$DisabledUsers
    )

    if ($DisabledUsers.Count -eq 0) {
        Write-Log "Nenhum usuário desativado encontrado." -Level "INFO"
        return
    }

    $totalUsers = $DisabledUsers.Count
    $currentUser = 0

    foreach ($user in $DisabledUsers) {
        $currentUser++
        $percentComplete = ($currentUser / $totalUsers) * 100
        Write-Progress -Activity "Movendo usuários desativados" -Status "$currentUser de $totalUsers" -PercentComplete $percentComplete

        try {
            if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Mover para a OU '$TargetOU'")) {
                Move-ADObject -Identity $user.DistinguishedName -TargetPath $TargetOU -ErrorAction Stop
                Write-Log "Usuário '$($user.SamAccountName)' movido para '$TargetOU'."
            }
        }
        catch {
            Write-Log "Falha ao mover o usuário '$($user.SamAccountName)': $($_.Exception.Message)" -Level "ERROR"
            continue
        }
    }
}

try {
    Write-Log "Iniciando script de movimentação de usuários desativados no AD."

    Import-ADModule
    $disabledUsers = Get-DisabledUsers
    Move-DisabledUsersToOU -TargetOU $MoveToOU -DisabledUsers $disabledUsers

    Write-Log "Script concluído com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}