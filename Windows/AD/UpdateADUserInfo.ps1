<#
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
    Autor: eduardo.agms@outlook.com.br
    Data: 27/01/2025
    Versão: 1.1
        Força output : UTF-8
    
.LINK
    Repositório: https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding()]
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

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Verbose "modulo ActiveDirectory importado com sucesso."
}
catch {
    Write-Error "Falha ao importar o modulo ActiveDirectory: $_"
    exit 1
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
    $usuarios = Import-Csv -Path $CsvPath -Encoding $Encoding -Delimiter $Delimiter
    Write-Host "CSV importado com sucesso. Total de Usuarios a processar: $($usuarios.Count)" -ForegroundColor Green
} catch {
    Write-Error "Falha ao importar o CSV: $_"
    exit 1
}

function Update-ADUserInfo {
    param (
        [array]$Users
    )

    foreach ($user in $Users) {
        try {
            if (-not $user.distinguishedName) {
                Write-Warning "distinguishedName ausente para o Usuario: $($user.sAMAccountName). Pulando atualizacao."
                continue
            }

            $adUser = Get-ADUser -Identity $user.distinguishedName -Properties *

            if (-not $adUser) {
                Write-Warning "Usuario nao encontrado no AD com distinguishedName: $($user.distinguishedName)."
                continue
            }

            $parameters = @{
                GivenName         = $user.givenName
                Surname           = $user.sn
                DisplayName       = $user.namedisplayNamecn
                SamAccountName    = $user.sAMAccountName
                Title             = $user.titledescription
                Description       = $user.titledescription
                Company           = $user.company
                Department        = $user.department
                StreetAddress     = $user.streetAddress
                City              = $user.l
                State             = $user.st
                PostalCode        = $user.postalCode
                Country           = $user.c
                OfficePhone       = $user.telephoneNumber
                EmployeeID        = $user.employeeID
            }

            Set-ADUser $adUser @parameters

            $replaceParams = @{
                Replace = @{
                    ipPhone     = $user.ipPhone
                    wWWHomePage = $WebPage
                    mail        = ($user.sAMAccountName + $DomainSuffix)
                }
            }

            Set-ADUser $adUser @replaceParams

            Rename-ADObject -Identity $user.distinguishedName -NewName $user.namedisplayNamecn

            Write-Host "Usuario atualizado com sucesso: $($user.sAMAccountName)" -ForegroundColor Cyan

        } catch {
            Write-Warning "Falha ao atualizar o Usuario $($user.sAMAccountName): $_"
        }
    }
}

Update-ADUserInfo -Users $usuarios