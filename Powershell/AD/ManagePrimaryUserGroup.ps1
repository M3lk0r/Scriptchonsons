<#
.SYNOPSIS
    Gerencia o grupo primeiro dos usuários em uma OU específica no Active Directory, adicinando um novo grupo primario e removendo o antigo.

.DESCRIPTION
    Este script realiza três operações principais:
    1. Adiciona um grupo específico a todos os usuários de uma OU.
    2. Define um grupo como o grupo principal para os usuários que são membros dele.
    3. Remove um grupo específico de todos os usuários de uma OU.

.PARAMETER OU
    Caminho da Unidade Organizacional (OU) onde os usuários estão localizados.

.PARAMETER GroupNameToAdd
    Nome do grupo a ser adicionado aos usuários.

.PARAMETER GroupNameToRemove
    Nome do grupo a ser removido dos usuários.

.EXAMPLE
    .\ManagePrimaryUserGroup.ps1 -OU "OU=Agripecas,DC=agripecas,DC=net" -GroupNameToAdd "Agripecas Users" -GroupNameToRemove "Domain Users"

.NOTES
    Autor: Eduardo Augusto Gomes(eduardo.agms@outlook.com.br)
    Data: 06/02/2025
    Versão: 2.1
        - Suporte otimizado para PowerShell 7.5
        - Melhor tratamento de erros
        - Aprimoramento no logging

.LINK
    https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Caminho da Unidade Organizacional (OU) onde os usuários estão localizados.")]
    [string]$OU,

    [Parameter(Mandatory = $true, HelpMessage = "Nome do grupo a ser adicionado aos usuários.")]
    [string]$GroupNameToAdd,

    [Parameter(Mandatory = $true, HelpMessage = "Nome do grupo a ser removido dos usuários.")]
    [string]$GroupNameToRemove
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$logFile = "C:\logs\ManageUserGroups.log"

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
        throw
    }
}

function Add-GroupToUsersInOU {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$OU,
        [string]$GroupNameToAdd
    )

    try {
        $users = Get-ADUser -Filter * -SearchBase $OU -ErrorAction Stop
        Write-Log "Usuários na OU '$OU' obtidos com sucesso. Total de usuários: $($users.Count)"
    }
    catch {
        Write-Log "Falha ao obter usuários da OU '$OU': $($_.Exception.Message)" -Level "ERROR"
        throw
    }

    $totalUsers = $users.Count
    $currentUser = 0

    foreach ($user in $users) {
        $currentUser++
        $percentComplete = ($currentUser / $totalUsers) * 100
        Write-Progress -Activity "Adicionando grupo '$GroupNameToAdd' aos usuários" -Status "$currentUser de $totalUsers" -PercentComplete $percentComplete

        try {
            if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Adicionar ao grupo '$GroupNameToAdd'")) {
                Add-ADGroupMember -Identity $GroupNameToAdd -Members $user.SamAccountName -ErrorAction Stop
                Write-Log "Usuário '$($user.SamAccountName)' adicionado ao grupo '$GroupNameToAdd'."
            }
        }
        catch {
            Write-Log "Falha ao adicionar o usuário '$($user.SamAccountName)' ao grupo '$GroupNameToAdd': $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

function Set-PrimaryGroupForUsersInOU {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$OU,
        [string]$GroupNameToAdd
    )

    try {
        $group = Get-ADGroup -Identity $GroupNameToAdd -Properties PrimaryGroupToken -ErrorAction Stop
        Write-Log "Grupo '$GroupNameToAdd' encontrado: $($group.DistinguishedName)"
    }
    catch {
        Write-Log "Falha ao obter o grupo '$GroupNameToAdd': $($_.Exception.Message)" -Level "ERROR"
        throw
    }

    $primaryGroupID = [string]$group.PrimaryGroupToken
    if ($null -eq $primaryGroupID -or $primaryGroupID -eq 0) {
        Write-Log "ID do grupo principal inválido para '$GroupNameToAdd'." -Level "ERROR"
        throw
    }

    try {
        $users = Get-ADUser -Filter * -SearchBase $OU -ErrorAction Stop
        Write-Log "Usuários na OU '$OU' obtidos com sucesso. Total de usuários: $($users.Count)"
    }
    catch {
        Write-Log "Falha ao obter usuários da OU '$OU': $($_.Exception.Message)" -Level "ERROR"
        throw
    }

    $totalUsers = $users.Count
    $currentUser = 0

    foreach ($user in $users) {
        $currentUser++
        $percentComplete = ($currentUser / $totalUsers) * 100
        Write-Progress -Activity "Definindo grupo principal para os usuários" -Status "$currentUser de $totalUsers" -PercentComplete $percentComplete

        try {
            $groupMemberships = Get-ADUser -Identity $user.SamAccountName -Property MemberOf | Select-Object -ExpandProperty MemberOf

            if ($groupMemberships -contains $group.DistinguishedName) {
                if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Definir grupo principal como '$GroupNameToAdd'")) {
                    Set-ADUser -Identity $user.SamAccountName -Replace @{primaryGroupID = $primaryGroupID } -ErrorAction Stop
                    Write-Log "Grupo principal definido como '$GroupNameToAdd' para o usuário '$($user.SamAccountName)'."
                }
            }
            else {
                Write-Log "Usuário '$($user.SamAccountName)' não é membro do grupo '$GroupNameToAdd'. Ignorando." -Level "WARNING"
            }
        }
        catch {
            Write-Log "Falha ao definir o grupo principal para o usuário '$($user.SamAccountName)': $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

function Remove-Group {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$OU,
        [string]$GroupNameToRemove
    )

    try {
        $groupToRemove = Get-ADGroup -Identity $GroupNameToRemove -Properties DistinguishedName -ErrorAction Stop
        Write-Log "Grupo '$GroupNameToRemove' encontrado: $($groupToRemove.DistinguishedName)"
    }
    catch {
        Write-Log "Falha ao obter o grupo '$GroupNameToRemove': $($_.Exception.Message)" -Level "ERROR"
        throw
    }

    try {
        $users = Get-ADUser -Filter * -SearchBase $OU -ErrorAction Stop
        Write-Log "Usuários na OU '$OU' obtidos com sucesso. Total de usuários: $($users.Count)"
    }
    catch {
        Write-Log "Falha ao obter usuários da OU '$OU': $($_.Exception.Message)" -Level "ERROR"
        throw
    }

    $totalUsers = $users.Count
    $currentUser = 0

    foreach ($user in $users) {
        $currentUser++
        $percentComplete = ($currentUser / $totalUsers) * 100
        Write-Progress -Activity "Removendo grupo '$GroupNameToRemove' dos usuários" -Status "$currentUser de $totalUsers" -PercentComplete $percentComplete

        try {
            $groupMemberships = Get-ADUser -Identity $user.SamAccountName -Property MemberOf | Select-Object -ExpandProperty MemberOf

            if ($groupMemberships -contains $groupToRemove.DistinguishedName) {
                if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Remover do grupo '$GroupNameToRemove'")) {
                    Remove-ADGroupMember -Identity $GroupNameToRemove -Members $user.SamAccountName -Confirm:$false -ErrorAction Stop
                    Write-Log "Grupo '$GroupNameToRemove' removido do usuário '$($user.SamAccountName)'."
                }
            }
        }
        catch {
            Write-Log "Falha ao remover o grupo '$GroupNameToRemove' do usuário '$($user.SamAccountName)': $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

try {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Log "Este script requer PowerShell 7.0 ou superior. Versão atual: $($PSVersionTable.PSVersion)" -Level "ERROR"
        exit 1
    }
    Write-Log "Iniciando script de gerenciamento de grupos de usuários no AD."

    Import-ADModule
    Add-GroupToUsersInOU -OU $OU -GroupNameToAdd $GroupNameToAdd
    Set-PrimaryGroupForUsersInOU -OU $OU -GroupNameToAdd $GroupNameToAdd
    Remove-Group -OU $OU -GroupNameToRemove $GroupNameToRemove

    Write-Log "Script concluído com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    throw
}