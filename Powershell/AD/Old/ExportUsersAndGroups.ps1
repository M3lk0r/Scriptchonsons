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
    Versão: 2.1
        Melhorias no manuseio de erros e otimização de consultas.

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

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$logFile = "C:\logs\ExportUsersAndGroups.log"

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    $dataHora = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$dataHora] [$Level] $Message"

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

function Export-UsersAndGroups {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$OU,
        [string]$OutputFile
    )

    try {
        $users = Get-ADUser -Filter * -SearchBase $OU -Properties DisplayName, MemberOf -ErrorAction Stop
        Write-Log "Usuários na OU '$OU' obtidos com sucesso. Total de usuários: $($users.Count)"
    }
    catch {
        Write-Log "Falha ao obter usuários da OU '$OU': $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }

    $totalUsers = $users.Count
    $currentUser = 0

    $usersInfo = @()

    foreach ($user in $users) {
        $currentUser++
        $percentComplete = ($currentUser / $totalUsers) * 100
        Write-Progress -Activity "Processando usuários" -Status "$currentUser de $totalUsers" -PercentComplete $percentComplete

        try {
            $groups = $user.MemberOf | ForEach-Object { (Get-ADGroup $_).Name }

            $userInfo = [PSCustomObject]@{
                Usuario           = $user.SamAccountName
                DisplayName       = $user.DisplayName
                distinguishedName = $user.DistinguishedName
                Grupos            = $groups -join ";"
            }

            $usersInfo += $userInfo
        }
        catch {
            Write-Log "Falha ao processar o usuário '$($user.SamAccountName)': $($_.Exception.Message)" -Level "ERROR"
        }
    }

    try {
        $usersInfo | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        Write-Log "Exportação concluída para: $OutputFile"
    }
    catch {
        Write-Log "Falha ao exportar o arquivo CSV: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

try {
    Write-Log "Iniciando script de exportação de usuários e grupos no AD."

    Import-ADModule
    Export-UsersAndGroups -OU $OU -OutputFile $OutputFile

    Write-Log "Script concluído com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}