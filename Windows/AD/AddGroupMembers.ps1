<#
.SYNOPSIS
    Adiciona membros de um grupo do Active Directory a outro grupo.

.DESCRIPTION
    Este script obtém os membros de um grupo de origem (sourceGroup) e os adiciona a um grupo de destino (targetGroup).
    O script suporta tratamento de erros, logging avançado, feedback visual durante a execução e verificação da versão do PowerShell.

.PARAMETER SourceGroup
    O nome do grupo de origem do qual os membros serão copiados.
    Exemplo: "GGD_ColaboradoresContoso1"

.PARAMETER TargetGroup
    O nome do grupo de destino ao qual os membros serão adicionados.
    Exemplo: "GGD_ColaboradoresContoso2"

.EXAMPLE
    .\AddGroupMembers.ps1 -SourceGroup "GGD_ColaboradoresContoso1" -TargetGroup "GGD_ColaboradoresContoso2"

.NOTES
    Autor: Eduardo Augusto Gomes (eduardo.agms@outlook.com.br)
    Data: 04/02/2025
    Versão: 3.2
        - Melhoria no log
        - Ajustes tecnicos

.LINK
    Repositório: https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Nome do grupo de origem.")]
    [string]$SourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "Nome do grupo de destino.")]
    [string]$TargetGroup
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$logFile = "C:\logs\AddGroupMembers.log"

function Write-Log {
    param (
        [string]$mensagem,
        [string]$Level = "INFO"
    )

    $dataHora = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$dataHora] [$Level] $mensagem"

    $logDir = [System.IO.Path]::GetDirectoryName($logFile)
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    if (-not (Test-Path $logFile)) {
        "" | Out-File -FilePath $logFile -Encoding UTF8
    }

    $logEntry | Out-File -FilePath $logFile -Encoding UTF8 -Append

    switch ($Level) {
        "INFO" { Write-Host $logEntry -ForegroundColor Green }
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        default { Write-Host $logEntry }
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

function Read-Permission {
    param (
        [string]$TargetGroup
    )

    try {
        Write-Log "Grupo '$TargetGroup' encontrado com sucesso."
        Add-ADGroupMember -Identity $TargetGroup -Members $testUser -WhatIf -ErrorAction Stop
        Write-Log "Usuário atual tem permissão para adicionar membros ao grupo '$TargetGroup'."
        return $true
    }
    catch {
        Write-Log "O usuário atual não tem permissão para adicionar membros ao grupo '$TargetGroup'. Script abortado." -Level "ERROR"
        exit 1
    }
}

function Add-MembersToGroup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$SourceGroup,
        [string]$TargetGroup
    )
    try {
        $userGroupMembers = Get-ADGroupMember -Identity $SourceGroup -ErrorAction Stop | Select-Object -ExpandProperty distinguishedName
        Write-Log "Membros do grupo '$SourceGroup' obtidos com sucesso. Total de membros: $($userGroupMembers.Count)"
    }
    catch {
        Write-Log "Falha ao obter membros do grupo '$SourceGroup': $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
    
    $totalMembers = $userGroupMembers.Count
    $currentMember = 0

    foreach ($user in $userGroupMembers) {
        $currentMember++
        $percentComplete = ($currentMember / $totalMembers) * 100
        Write-Progress -Activity "Adicionando membros ao grupo '$TargetGroup'" -Status "$currentMember de $totalMembers" -PercentComplete $percentComplete

        try {
            if ($PSCmdlet.ShouldProcess($user, "Adicionar ao grupo '$TargetGroup'")) {
                Add-ADGroupMember -Identity $TargetGroup -Members $user -ErrorAction Stop
                Write-Log "Usuário '$user' adicionado ao grupo '$TargetGroup'."
            }
        }
        catch {
            Write-Log "Falha ao adicionar o usuário '$user' ao grupo '$TargetGroup': $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Log "Este script requer PowerShell 7.0 ou superior. Versão atual: $($PSVersionTable.PSVersion)" -Level "ERROR"
    exit 1
}

try {
    Write-Log "Iniciando script de adição de membros de grupo no AD."
    Import-ADModule

    if (-not (Read-Permission -TargetGroup $TargetGroup)) {
        Write-Log "O usuário atual não tem permissão para adicionar membros ao grupo '$TargetGroup'. Script abortado." -Level "ERROR"
        exit 1
    }

    Add-MembersToGroup -SourceGroup $SourceGroup -TargetGroup $TargetGroup
    Write-Log "Script concluído com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}