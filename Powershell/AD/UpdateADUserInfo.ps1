﻿<#
.SYNOPSIS
    Atualiza informações dos Usuarios no Active Directory a partir de um arquivo CSV.

.DESCRIPTION
    Este script importa dados de Usuarios a partir de um arquivo CSV, onde cada coluna corresponde a um atributo do Usuario no Active Directory.
    Os Usuarios são identificados pelo `distinguishedName` e suas informações são atualizadas conforme os dados fornecidos no CSV.
    O script suporta caracteres especiais através da codificação UTF-8.

.PARAMETER CsvPath
    O caminho completo para o arquivo CSV que contém as informações dos Usuarios a serem atualizados.
    Exemplo: "C:\csv\updategeral.csv"

.PARAMETER Delimiter
    O delimitador utilizado no arquivo CSV.

.PARAMETER Encoding
    A codificação do arquivo CSV. Por padrão, é definido como "UTF8" para suportar caracteres especiais.

.PARAMETER DomainSuffix
    O sufixo do domínio a ser utilizado para construir o endereço de e-mail dos Usuarios.
    Exemplo: "@contoso.local"

.PARAMETER WebPage
    A URL da página inicial a ser atribuída aos Usuarios.

.EXAMPLE
    .\UpdateADUserInfo.ps1 -CsvPath "C:\csv\updategeral.csv" -Delimiter ";" -Encoding "UTF8" -DomainSuffix "@contoso.local" -WebPage "https://www.contoso.local/"

.NOTES
    Autor: Eduardo Augusto Gomes(eduardo.agms@outlook.com.br)
    Data: 06/02/2025
    Versão: 2.0
        - Suporte otimizado para PowerShell 7.5
        - Melhor tratamento de erros
        - Aprimoramento no logging
    
.LINK
    Repositório: https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Diretorio do arquivo CSV a ser importado.")]
    [string]$CsvPath,

    [Parameter(Mandatory = $false, HelpMessage = "Delimitação do CSV (, ou ;),padrão (;).")]
    [string]$Delimiter = ";",

    [Parameter(Mandatory = $false, HelpMessage = "Encode para importação das informações, padrão (UTF8).")]
    [string]$Encoding = "utf8",

    [Parameter(Mandatory = $false, HelpMessage = "Sufixo para email, exemplo: @contoso.local.")]
    [string]$DomainSuffix,

    [Parameter(Mandatory = $false, HelpMessage = "Website para atribuição aos Usuarios, exemplo: https://www.contoso.local/.")]
    [string]$WebPage
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$logDir = "C:\logs\UpdateADUserInfo.log"

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
        Write-Host "Erro ao escrever no log: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

function Get-PSVersion {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Log "Este script requer PowerShell 7.0 ou superior. Versão atual: $($PSVersionTable.PSVersion)" -Level "ERROR"
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

function Update-ADUserInfo {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [array]$Users
    )

    foreach ($user in $Users) {
        try {
            if (-not $user.distinguishedName) {
                Write-Log "distinguishedName ausente para o Usuario: $($user.sAMAccountName). Pulando atualizacao." -Level "WARNING"
                continue
            }

            $adUser = Get-ADUser -Identity $user.distinguishedName -Properties *

            if (-not $adUser) {
                Write-Log "Usuario nao encontrado no AD com distinguishedName: $($user.distinguishedName)." -Level "WARNING"
                continue
            }

            $parameters = @{
                GivenName      = $user.givenName
                Surname        = $user.sn
                DisplayName    = $user.namedisplayNamecn
                SamAccountName = $user.sAMAccountName
                Title          = $user.titledescription
                Description    = $user.titledescription
                Company        = $user.company
                Department     = $user.department
                StreetAddress  = $user.streetAddress
                City           = $user.l
                State          = $user.st
                PostalCode     = $user.postalCode
                Country        = $user.c
                OfficePhone    = $user.telephoneNumber
                EmployeeID     = $user.employeeID
            }

            Set-ADUser $adUser @parameters

            $replaceParams = @{
                Replace = @{
                    ipPhone     = $user.ipPhone
                    wWWHomePage = $WebPage
                    mail        = ($user.sAMAccountName + $DomainSuffix)
                }
            }

            Set-ADUser $adUser @replaceParams -ErrorAction Stop

            Rename-ADObject `
                -Identity $user.distinguishedName `
                -NewName $user.namedisplayNamecn `
                -ErrorAction Stop

            Write-Log "Usuario atualizado com sucesso: $($user.sAMAccountName)" 

        }
        catch {
            Write-Log "Falha ao atualizar o Usuario $($user.sAMAccountName): $($_.Exception.Message)" -Level "Error"
        }
    }
}

try {
    Write-Log "Iniciando script."

    Get-PSVersion

    Import-ADModule

    try {
        $usuarios = Import-Csv -Path $CsvPath -Encoding $Encoding -Delimiter $Delimiter
        Write-Log "CSV importado com sucesso. Total de Usuarios a processar: $($usuarios.Count)"
    }
    catch {
        Write-Error "Falha ao importar o CSV: $($_.Exception.Message)"
        exit 1
    }
    Update-ADUserInfo -Users $usuarios
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}