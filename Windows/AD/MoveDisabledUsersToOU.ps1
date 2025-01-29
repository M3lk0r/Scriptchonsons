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
    Versão: 2.0
        Versão aprimorada com validações, logging, suporte a pipeline, tratamento de erros robusto e boas práticas do PowerShell 7.4.

.LINK
    https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Caminho da Unidade Organizacional (OU) de destino para onde os usuários desativados serão movidos.")]
    [string]$MoveToOU
)

# Configurações iniciais
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$logFile = "C:\logs\MoveDisabledUsersToOU.log"

# Função para escrever logs
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry
}

# Função para importar o módulo ActiveDirectory
function Import-ADModule {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        Write-Log "Módulo ActiveDirectory importado com sucesso."
    }
    catch {
        Write-Log "Falha ao importar o módulo ActiveDirectory: $_" -Level "ERROR"
        throw
    }
}

# Função para mover usuários desativados para a OU especificada
function Move-DisabledUsersToOU {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$TargetOU
    )

    try {
        # Obtém todos os usuários desativados
        $disabledUsers = Get-ADUser -Filter { Enabled -eq $false } -Properties DistinguishedName -ErrorAction Stop
        Write-Log "Usuários desativados obtidos com sucesso. Total de usuários: $($disabledUsers.Count)"
    }
    catch {
        Write-Log "Falha ao obter usuários desativados: $_" -Level "ERROR"
        throw
    }

    # Verifica se há usuários desativados encontrados
    if ($disabledUsers.Count -eq 0) {
        Write-Log "Nenhum usuário desativado encontrado." -Level "INFO"
        return
    }

    $totalUsers = $disabledUsers.Count
    $currentUser = 0

    foreach ($user in $disabledUsers) {
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
            Write-Log "Falha ao mover o usuário '$($user.SamAccountName)': $_" -Level "ERROR"
        }
    }
}

# Início do script
try {
    Write-Log "Iniciando script de movimentação de usuários desativados no AD."

    Import-ADModule
    Move-DisabledUsersToOU -TargetOU $MoveToOU

    Write-Log "Script concluído com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $_" -Level "ERROR"
    throw
}