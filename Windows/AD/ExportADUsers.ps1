<#
.SYNOPSIS
    Exporta informações de usuários no Active Directory e seus grupos de pertença.

.DESCRIPTION
    Este script exporta dados de usuários em uma Unidade Organizacional (OU) especificada no Active Directory.
    Ele pode filtrar usuários ativos, desabilitados ou ambos, incluindo o status do usuário no resultado.

.PARAMETER OU
    A Unidade Organizacional (OU) a partir da qual os usuários serão listados.
    Exemplo: "OU=Users,DC=contoso,DC=local"

.PARAMETER OutputDir
    Caminho do diretório onde o arquivo CSV será salvo. O nome do arquivo será gerado automaticamente.
    Exemplo: "C:\export"

.PARAMETER UserStatus
    Define se os usuários a serem exportados são habilitados, desabilitados ou ambos.
    Valores possíveis: "Habilitados", "Desabilitados", "Todos".
    O padrão é "Todos".

.EXAMPLE
    .\ExportADUsers.ps1 -OU "OU=Users,DC=contoso,DC=local" -OutputDir "C:\export" -UserStatus "Habilitado"

.NOTES
    Autor: Eduardo Augusto Gomes (eduardo.agms@outlook.com.br)
    Data: 05/02/2025
    Versão: 2.4
        - Geração automática do nome do arquivo CSV com data e hora
        - Melhor tratamento de erros e logging
        - Suporte otimizado para PowerShell 7.5

.LINK
    Repositório: https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Unidade Organizacional do AD a ser pesquisada.")]
    [string]$OU,

    [Parameter(Mandatory = $true, HelpMessage = "Diretório onde o arquivo CSV será salvo.")]
    [string]$OutputDir,

    [Parameter(Mandatory = $false, HelpMessage = "Status dos usuários: Habilitado, Desabilitado ou Todos.")]
    [ValidateSet("Habilitados", "Desabilitados", "Todos")]
    [string]$UserStatus = "Todos"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$logFile = "C:\logs\ExportADUsers.log"

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

try {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Log "Este script requer PowerShell 7.0 ou superior. Versão atual: $($PSVersionTable.PSVersion)" -Level "ERROR"
        exit 1
    }
    
    $dataHora = Get-Date -Format "yyyy-MM-dd HH-mm-ss"
    $OutputFile = "$OutputDir\ExportADUsers_$dataHora.csv"

    Import-ADModule

    switch ($UserStatus) {
        "Habilitados" { $filter = "(!userAccountControl:1.2.840.113556.1.4.803:=2)" }
        "Desabilitados" { $filter = "(userAccountControl:1.2.840.113556.1.4.803:=2)" }
        "Todos" { $filter = "(objectClass=user)" }
    }

    try {
        $users = Get-ADUser -LDAPFilter $filter -SearchBase $OU -Properties SamAccountName, DisplayName, Title, Department, Enabled, MemberOf
        Write-Log "Usuários encontrados: $($users.Count)" -Level "INFO"
    }
    catch {
        Write-Log "Falha ao buscar usuários no Active Directory: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }

    $usersInfo = @()

    foreach ($user in $users) {
        $groups = $user.MemberOf | ForEach-Object { (Get-ADGroup $_).Name }

        $userInfo = [PSCustomObject]@{
            Usuario           = $user.SamAccountName
            DisplayName       = $user.DisplayName
            Title             = $user.Title
            Department        = $user.Department
            Status            = $user.Enabled ? "Habilitado" : "Desabilitado"
            distinguishedName = $user.DistinguishedName
            Grupos            = $groups -join ";"
        }

        $usersInfo += $userInfo
    }

    try {
        $usersInfo | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
        Write-Log "Exportação concluída para: $OutputFile" -Level "INFO"
    }
    catch {
        Write-Log "Falha ao exportar os dados para CSV: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
