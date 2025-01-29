<#
.SYNOPSIS
    Exporta informações de usuários no Active Directory e seus grupos de pertença.

.DESCRIPTION
    Este script exporta dados de usuários em uma Unidade Organizacional (OU) especificada no Active Directory.
    Ele pode filtrar usuários ativos, desabilitados ou ambos, incluindo o status do usuário no resultado.

.PARAMETER OU
    A Unidade Organizacional (OU) a partir da qual os usuários serão listados.
    Exemplo: "OU=Users,DC=contoso,DC=local"

.PARAMETER OutputFile
    Caminho completo para o arquivo CSV onde as informações serão exportadas.
    Exemplo: "C:\export\usuarios_grupos.csv"

.PARAMETER UserStatus
    Define se os usuários a serem exportados são habilitado, desabilitados ou ambos.
    Valores possíveis: "Habilitado", "Desabilitado", "Todos".
    O padrão é "Todos".

.EXAMPLE
    .\ExportADUsers.ps1 -OU "OU=Users,DC=contoso,DC=local" -OutputFile "C:\export\usuarios_grupos.csv" -UserStatus "Habilitado"

.NOTES
    Autor: Eduardo Augusto Gomes(eduardo.agms@outlook.com.br)
    Data: 29/01/2025
    Versão: 2.1
        Força output : UTF-8

.LINK
    Repositório: https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Unidade Organizacional do AD a ser pesquisada.")]
    [string]$OU,

    [Parameter(Mandatory = $true, HelpMessage = "Caminho para o arquivo CSV de saída.")]
    [string]$OutputFile,

    [Parameter(Mandatory = $false, HelpMessage = "Status dos usuários: Habilitado, Desabilitado ou Todos.")]
    [ValidateSet("Habilitado", "Desabilitado", "Todos")]
    [string]$UserStatus = "Todos"
)

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Verbose "Módulo ActiveDirectory importado com sucesso."
} catch {
    Write-Error "Falha ao importar o módulo ActiveDirectory: $_"
    exit 1
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$usersInfo = @()

switch ($UserStatus) {
    "Habilitado"       { $filter = "Enabled -eq \$true" }
    "Desabilitado" { $filter = "Enabled -eq \$false" }
    "Todos"       { $filter = "*" }
}

$users = Get-ADUser -Filter $filter -SearchBase $OU -Properties *

foreach ($user in $users) {
    $groups = (Get-ADUser $user.SamAccountName -Properties MemberOf).MemberOf |
        ForEach-Object { (Get-ADGroup $_).Name }

    $userInfo = [PSCustomObject]@{
        #OU          = $OU
        Usuario     = $user.SamAccountName
        DisplayName = $user.DisplayName
        Title       = $user.Title
        Department  = $user.Department
        Status      = if ($user.Enabled) { "Habilitado" } else { "Desabilitado" }
        #Grupos      = $groups -join ";"
    }

    $usersInfo += $userInfo
}

$usersInfo | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8

Write-Host "Exportação concluída para: $OutputFile"
