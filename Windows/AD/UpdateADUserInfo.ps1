<#
.SYNOPSIS
    Atualiza informações dos usuários no Active Directory a partir de um arquivo CSV.

.DESCRIPTION
    Este script importa dados de usuários a partir de um arquivo CSV, onde cada coluna corresponde a um atributo do usuário no Active Directory.
    Os usuários são identificados pelo `distinguishedName` e suas informações são atualizadas conforme os dados fornecidos no CSV.
    O script suporta caracteres especiais através da codificação UTF-8.

.PARAMETER CsvPath
    O caminho completo para o arquivo CSV que contém as informações dos usuários a serem atualizados.
    Exemplo: "C:\csv\updategeral.csv"

.PARAMETER Delimiter
    O delimitador utilizado no arquivo CSV.

.PARAMETER Encoding
    A codificação do arquivo CSV. Por padrão, é definido como "UTF8" para suportar caracteres especiais.

.PARAMETER DomainSuffix
    O sufixo do domínio a ser utilizado para construir o endereço de e-mail dos usuários.
    Exemplo: "@contoso.local"

.PARAMETER WebPage
    A URL da página inicial a ser atribuída aos usuários.

.EXAMPLE
    .\UpdateADUserInfo.ps1 -CsvPath "C:\csv\updategeral.csv" -Delimiter ";" -Encoding "UTF8" -DomainSuffix "@contoso.local" -WebPage "https://www.contoso.local/"

.NOTES
    Autor: eduardo.agms@outlook.com.br
    Data: 27/04/2024
    Versão: 1.0
        Versão inicial do script.
    
.LINK
    Repositório: https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true), HelpMessage = "Diretório do arquivo CSV a ser importado."]
    [string]$CsvPath,

    [Parameter(Mandatory = $false), HelpMessage = "Delimitação do CSV (, ou ;)."]
    [string]$Delimiter = ';',

    [Parameter(Mandatory = $false), HelpMessage = "Encode para importação das informações, padrão UTF8."]
    [string]$Encoding = "UTF8",

    [Parameter(Mandatory = $false), HelpMessage = "Sufixo para email, exemplo: @contoso.local."]
    [string]$DomainSuffix,

    [Parameter(Mandatory = $false), HelpMessage = "Website para atribuição aos usuários, exemplo: https://www.contoso.local/."]
    [string]$WebPage
)

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Verbose "Módulo ActiveDirectory importado com sucesso."
}
catch {
    Write-Error "Falha ao importar o módulo ActiveDirectory: $_"
    exit 1
}

# Importa os dados do CSV com a codificação especificada
try {
    $usuarios = Import-Csv -Path $CsvPath -Delimiter $Delimiter -Encoding $Encoding
    Write-Host "CSV importado com sucesso. Total de usuários a processar: $($usuarios.Count)" -ForegroundColor Green
} catch {
    Write-Error "Falha ao importar o CSV: $_"
    exit 1
}

# Função para atualizar informações dos usuários no Active Directory
function Update-ADUserInfo {
    param (
        [array]$Users
    )

    foreach ($user in $Users) {
        try {
            # Verifica se o distinguishedName está presente
            if (-not $user.distinguishedName) {
                Write-Warning "distinguishedName ausente para o usuário: $($user.sAMAccountName). Pulando atualização."
                continue
            }

            # Obtém o usuário do Active Directory pelo distinguishedName
            $adUser = Get-ADUser -Filter { DistinguishedName -eq $user.distinguishedName } -Properties *

            if (-not $adUser) {
                Write-Warning "Usuário não encontrado no AD com distinguishedName: $($user.distinguishedName)."
                continue
            }

            # Prepara os parâmetros para atualização
            $parameters = @{
                GivenName         = $user.givenName
                Surname           = $user.sn
                DisplayName       = $user.namedisplayNamecn
                Name              = $user.namedisplayNamecn
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
                CountryCode       = $user.countryCode
                OfficePhone       = $user.telephoneNumber
                EmployeeID        = $user.employeeID
            }

            # Atualiza os atributos básicos via parâmetros
            Set-ADUser $adUser @parameters

            # Atualiza atributos que requerem -Replace
            $replaceParams = @{
                Replace = @{
                    ipPhone     = $user.ipPhone
                    wWWHomePage = $WebPage
                    mail        = ($user.sAMAccountName + $DomainSuffix)
                }
            }

            Set-ADUser $adUser @replaceParams

            Write-Host "Usuário atualizado com sucesso: $($user.sAMAccountName)" -ForegroundColor Cyan

        } catch {
            Write-Warning "Falha ao atualizar o usuário $($user.sAMAccountName): $_"
        }
    }
}

# Executa a função de atualização
Update-ADUserInfo -Users $usuarios