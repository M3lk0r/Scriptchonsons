<#
.SYNOPSIS
    Adiciona membros de um grupo do Active Directory a outro grupo.

.DESCRIPTION
    Este script obtém os membros de um grupo de origem (sourceGroup) e os adiciona a um grupo de destino (targetGroup).
    O script suporta tratamento de erros, logging avançado, feedback visual durante a execução e verificação da versão do PowerShell.

.PARAMETER SourceGroup
    O nome do grupo de origem do qual os membros serão copiados.
    Exemplo: "GGD_ColaboradoresDaimo"

.PARAMETER TargetGroup
    O nome do grupo de destino ao qual os membros serão adicionados.
    Exemplo: "GGD_ColaboradoresDaimo1"

.EXAMPLE
    .\AddGroupMembers.ps1 -SourceGroup "GGD_ColaboradoresDaimo" -TargetGroup "GGD_ColaboradoresDaimo1"

.NOTES
    Autor: Eduardo Augusto Gomes (eduardo.agms@outlook.com.br)
    Data: 29/01/2025
    Versão: 3.0
        - Adicionada verificação da versão do PowerShell
        - Melhorias no logging com Write-Host para feedback visual
        - Otimização no uso de Write-Progress
        - Modularização para melhor manutenção e reutilização do código

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

# Configurações iniciais
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$logFile = "C:\logs\AddGroupMembers.log"

# Verifica versão do PowerShell
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "[ERRO] Este script requer PowerShell 7.0 ou superior." -ForegroundColor Red
    exit 1
}

# Função para escrever logs
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry
    Write-Host $logEntry -ForegroundColor (if ($Level -eq "ERROR") { "Red" } else { "Green" })
}

# Função para importar o módulo ActiveDirectory
function Import-ADModule {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        Write-Log "Módulo ActiveDirectory importado com sucesso."
    }
    catch {
        Write-Log "Falha ao importar o módulo ActiveDirectory: $_" -Level "ERROR"
        exit 1
    }
}

# Função para adicionar membros de um grupo a outro
function Add-MembersToGroup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$SourceGroup,
        [string]$TargetGroup
    )
    try {
        # Obtém os membros do grupo de origem
        $userGroupMembers = Get-ADGroupMember -Identity $SourceGroup -ErrorAction Stop | Select-Object -ExpandProperty distinguishedName
        Write-Log "Membros do grupo '$SourceGroup' obtidos com sucesso. Total de membros: $($userGroupMembers.Count)"
    }
    catch {
        Write-Log "Falha ao obter membros do grupo '$SourceGroup': $_" -Level "ERROR"
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
            Write-Log "Falha ao adicionar o usuário '$user' ao grupo '$TargetGroup': $_" -Level "ERROR"
        }
    }
}

# Início do script
try {
    Write-Log "Iniciando script de adição de membros de grupo no AD."
    Import-ADModule
    Add-MembersToGroup -SourceGroup $SourceGroup -TargetGroup $TargetGroup
    Write-Log "Script concluído com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $_" -Level "ERROR"
    exit 1
}