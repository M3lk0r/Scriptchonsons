<#
.SYNOPSIS
    Exporta informações de usuários e seus grupos de uma Unidade Organizacional (OU) específica para um arquivo CSV.

.DESCRIPTION
    Este script localiza todos os usuários em uma OU especificada, obtém os grupos aos quais pertencem e exporta essas informações para um arquivo CSV.
    O script suporta tratamento de erros, logging e feedback visual durante a execução.

.PARAMETER OU
    Caminho da Unidade Organizacional (OU) onde os usuários estão localizados.

.PARAMETER OutputFile
    Caminho completo do arquivo CSV onde as informações serão exportadas.

.EXAMPLE
    .\ExportUsersAndGroups.ps1 -OU "OU=Agripecas,DC=agripecas,DC=net" -OutputFile "C:\export\usuarios_grupos.csv"

.NOTES
    Autor: Eduardo Augusto Gomes
    Data: 18/12/2024
    Versão: 2.0
        Versão aprimorada com validações, logging, suporte a pipeline, tratamento de erros robusto e boas práticas do PowerShell 7.4.

.LINK
    https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Caminho da Unidade Organizacional (OU) onde os usuários estão localizados.")]
    [string]$OU,

    [Parameter(Mandatory = $true, HelpMessage = "Caminho completo do arquivo CSV onde as informações serão exportadas.")]
    [string]$OutputFile
)

# Configurações iniciais
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$logFile = "C:\logs\ExportUsersAndGroups.log"

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

# Função para exportar informações de usuários e grupos
function Export-UsersAndGroups {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$OU,
        [string]$OutputFile
    )

    try {
        # Obtém todos os usuários na OU especificada
        $users = Get-ADUser -Filter * -SearchBase $OU -Properties DisplayName, MemberOf -ErrorAction Stop
        Write-Log "Usuários na OU '$OU' obtidos com sucesso. Total de usuários: $($users.Count)"
    }
    catch {
        Write-Log "Falha ao obter usuários da OU '$OU': $_" -Level "ERROR"
        throw
    }

    $totalUsers = $users.Count
    $currentUser = 0

    # Inicializa uma lista para armazenar as informações
    $usersInfo = @()

    foreach ($user in $users) {
        $currentUser++
        $percentComplete = ($currentUser / $totalUsers) * 100
        Write-Progress -Activity "Processando usuários" -Status "$currentUser de $totalUsers" -PercentComplete $percentComplete

        try {
            # Obtém os grupos do usuário
            $groups = $user.MemberOf | ForEach-Object { (Get-ADGroup $_).Name }

            # Cria um objeto com as informações desejadas
            $userInfo = [PSCustomObject]@{
                Usuario     = $user.SamAccountName
                DisplayName = $user.DisplayName
                distinguishedName = $user.DistinguishedName
                Grupos      = $groups -join ";"
            }

            # Adiciona o objeto à lista
            $usersInfo += $userInfo
        }
        catch {
            Write-Log "Falha ao processar o usuário '$($user.SamAccountName)': $_" -Level "ERROR"
        }
    }

    try {
        # Exporta a lista de informações para um arquivo CSV
        $usersInfo | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        Write-Log "Exportação concluída para: $OutputFile"
    }
    catch {
        Write-Log "Falha ao exportar o arquivo CSV: $_" -Level "ERROR"
        throw
    }
}

# Início do script
try {
    Write-Log "Iniciando script de exportação de usuários e grupos no AD."

    Import-ADModule
    Export-UsersAndGroups -OU $OU -OutputFile $OutputFile

    Write-Log "Script concluído com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $_" -Level "ERROR"
    throw
}