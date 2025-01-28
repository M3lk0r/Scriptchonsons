<#
.SYNOPSIS
    Cria e atualiza informações dos usuários no Active Directory a partir de um arquivo CSV.

.DESCRIPTION
    Este script importa dados de usuários a partir de um arquivo CSV, onde cada coluna corresponde a um atributo do usuário no Active Directory.
    Os usuários são criados se não existirem e atualizados caso já estejam presentes no AD.
    A criação e atualização de usuários são mantidas em funções separadas para garantir que os usuários sejam criados com os atributos essenciais antes de qualquer atualização adicional.
    A criação de endereços de e-mail personalizados com ProxyAddresses também é suportada.

.PARAMETER CsvPath
    O caminho completo para o arquivo CSV que contém as informações dos usuários a serem criados ou atualizados.
    Exemplo: "C:\csv\newusers.csv"

.PARAMETER Delimiter
    O delimitador utilizado no arquivo CSV. Padrão: ";"

.PARAMETER Encoding
    A codificação do arquivo CSV. Padrão: "UTF8"

.PARAMETER DefaultPassword
    A senha padrão para os novos usuários. Padrão: "mudar@123"

.PARAMETER DomainSuffix
    O sufixo do domínio a ser utilizado para construir o usuário.
    Exemplo: "@contoso.local"

.PARAMETER UpnDomain
    (Opcional) Domínio UPN a ser usado para UserPrincipalName. Se não for definido, será utilizado o DomainSuffix.
    Exemplo: "@example.com"

.PARAMETER SecondaryEmailDomain
    (Opcional) Domínio secundário para endereços de e-mail. Se definido, será adicionado como smtp secundário.
    Exemplo: "@secondarydomain.com"

.PARAMETER WebsiteURL
    A URL da página inicial a ser atribuída aos usuários.
    Exemplo: "https://contoso.local"

.PARAMETER Country
    O país a ser atribuído aos usuários. Padrão: "BR"

.EXAMPLE
    .\AddNewUsersFromCSV.ps1 -CsvPath "C:\csv\newusers.csv" -Delimiter ";" -Encoding "UTF8" `
        -DefaultPassword "mudar@123" -DomainSuffix "@contoso.local" `
        -UpnDomain "@example.com" -SecondaryEmailDomain "@secondary.com" `
        -WebsiteURL "https://contoso.local" -Country "BR"

.NOTES
    Autor: eduardo.agms@outlook.com.br
    Data: 28/01/2025
    Versão: 2.2
        Versão aprimorada com parametrização opcional para domínio UPN e configuração de ProxyAddresses.

.LINK
    Repositório: https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Caminho completo para o arquivo CSV a ser importado.")]
    [string]$CsvPath,

    [Parameter(Mandatory = $false, HelpMessage = "Delimitador do CSV. Padrão: ';'")]
    [string]$Delimiter = ";",

    [Parameter(Mandatory = $false, HelpMessage = "Codificação do arquivo CSV. Padrão: 'UTF8'")]
    [string]$Encoding = "UTF8",

    [Parameter(Mandatory = $false, HelpMessage = "Senha padrão para novos usuários. Padrão: 'mudar@123'")]
    [string]$DefaultPassword = "mudar@123",

    [Parameter(Mandatory = $true, HelpMessage = "Sufixo do domínio a ser utilizado para construir o usuário. Exemplo: '@contoso.local'")]
    [string]$DomainSuffix,

    [Parameter(Mandatory = $false, HelpMessage = "Domínio UPN a ser usado para UserPrincipalName. Se não for definido, será utilizado o DomainSuffix. Exemplo: '@contoso.local'")]
    [string]$UpnDomain,

    [Parameter(Mandatory = $false, HelpMessage = "Domínio secundário para endereços de e-mail. Se definido, será adicionado como smtp secundário. Exemplo: '@secondary.local'")]
    [string]$SecondaryEmailDomain,

    [Parameter(Mandatory = $false, HelpMessage = "URL da página inicial a ser atribuída aos usuários.")]
    [string]$WebsiteURL = "",

    [Parameter(Mandatory = $false, HelpMessage = "País a ser atribuído aos usuários. Padrão: 'BR'")]
    [string]$Country = "BR"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Import-ADModule {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        Write-Verbose "Módulo ActiveDirectory importado com sucesso."
    }
    catch {
        Write-Error "Falha ao importar o módulo ActiveDirectory: $_"
        exit 1
    }
}

function Import-UserCSV {
    param (
        [string]$Path,
        [string]$Delimiter,
        [string]$Encoding
    )

    try {
        $data = Import-Csv -Path $Path -Delimiter $Delimiter -Encoding $Encoding
        Write-Host "CSV importado com sucesso. Total de usuários a processar: $($data.Count)" -ForegroundColor Green
        return $data
    }
    catch {
        Write-Error "Falha ao importar o CSV: $_"
        exit 1
    }
}

function Create-Users {
    param (
        [array]$Users,
        [SecureString]$Password,
        [string]$DomainSuffix,
        [string]$UpnDomain,
        [string]$SecondaryEmailDomain
    )

    foreach ($user in $Users) {
        try {
            if (-not $user.sAMAccountName) {
                Write-Error "O campo sAMAccountName está vazio ou não definido. Verifique os dados do usuário."
                return
            }

            if (-not $user) {
                Write-Error "O objeto 'user' está vazio ou não definido."
                return
            }
            if (-not $user.PSObject.Properties.Match("sAMAccountName")) {
                Write-Error "O objeto 'user' não possui a propriedade 'sAMAccountName'."
                return
            }
            $existingUser = Get-ADUser -Filter "SamAccountName -eq '$($user.sAMAccountName)'"

            if ($null -eq $existingUser) {
            
                if ($UpnDomain) {
                    $userUpn = "$($user.sAMAccountName)$UpnDomain"
                }
                else {
                    $userUpn = "$($user.sAMAccountName)$DomainSuffix"
                }

                New-ADUser `
                    -GivenName $user.givenName `
                    -Surname $user.sn `
                    -SamAccountName $user.sAMAccountName `
                    -DisplayName $user.namedisplayNamecn `
                    -Name $user.namedisplayNamecn `
                    -Description $user.titledescription `
                    -Department $user.Department `
                    -Title $user.titledescription `
                    -UserPrincipalName $userUpn `
                    -Path $user.ou `
                    -AccountPassword $Password `
                    -Enabled $true `
                    -ChangePasswordAtLogon $true

                $proxyAddresses = @()

                $proxyAddresses += "SMTP:$userUpn"

                if ($SecondaryEmailDomain) {
                    $secondaryEmail = "$($user.sAMAccountName)@$SecondaryEmailDomain"
                    $proxyAddresses += "smtp:$secondaryEmail"
                }

                Set-ADUser -Identity $user.sAMAccountName -Replace @{proxyAddresses = $proxyAddresses }

                Write-Host "Usuário '$($user.sAMAccountName)' criado com sucesso com ProxyAddresses configurado." -ForegroundColor Cyan
            
            }
            else {
                Write-Host "Usuário '$($user.sAMAccountName)' já existe. Pulando criação." -ForegroundColor Yellow
            }
        }
        catch {
            Write-Warning "Erro ao criar usuário '$($user.sAMAccountName)': $_"
        }
    }
}

function Update-Users {
    param (
        [array]$Users,
        [string]$WebsiteURL,
        [string]$DomainSuffix,
        [string]$Country,
        [string]$UpnDomain,
        [string]$SecondaryEmailDomain
    )

    foreach ($user in $Users) {
        try {
            $adUser = Get-ADUser -Identity $user.sAMAccountName -Properties *

            if ($adUser) {
                $setParams = @{
                    Office        = $user.Office
                    Surname       = $user.sn
                    Company       = $user.Company
                    StreetAddress = $user.StreetAddress
                    Description   = $user.titledescription
                    Department    = $user.Department
                    Title         = $user.titledescription
                    City          = $user.City
                    State         = $user.State
                    Country       = $Country
                    PostalCode    = $user.postalCode
                }

                $replaceParams = @{
                    'ipPhone'         = $user.ipPhone
                    'wWWHomePage'     = $WebsiteURL
                    'telephoneNumber' = $user.telephoneNumber
                }

                if ($UpnDomain) {
                    $newUpn = "$($user.sAMAccountName)$UpnDomain"
                }
                else {
                    $newUpn = "$($user.sAMAccountName)$DomainSuffix"
                }

                $setParams['UserPrincipalName'] = $newUpn

                $replaceParams['mail'] = $newUpn

                $proxyAddresses = @()

                $proxyAddresses += "SMTP:$newUpn"

                if ($SecondaryEmailDomain) {
                    $secondaryEmail = "$($user.sAMAccountName)$SecondaryEmailDomain"
                    $proxyAddresses += "smtp:$secondaryEmail"
                }

                $replaceParams['proxyAddresses'] = $proxyAddresses

                Set-ADUser -Identity $adUser @setParams
                Set-ADUser -Identity $adUser -Replace $replaceParams

                Write-Host "Usuário '$($user.sAMAccountName)' atualizado com sucesso e ProxyAddresses configurado." -ForegroundColor Cyan
            }
            else {
                Write-Warning "Usuário '$($user.sAMAccountName)' não encontrado no AD. Pulando atualização."
            }
        }
        catch {
            Write-Warning "Erro ao atualizar usuário '$($user.sAMAccountName)': $_"
        }
    }
}

$sAMAccountNames = Import-UserCSV -Path $CsvPath -Delimiter $Delimiter -Encoding $Encoding

$securePassword = ConvertTo-SecureString -String $DefaultPassword -AsPlainText -Force

Create-Users -Users $sAMAccountNames -Password $securePassword -DomainSuffix $DomainSuffix -UpnDomain $UpnDomain -SecondaryEmailDomain $SecondaryEmailDomain

Update-Users -Users $sAMAccountNames -WebsiteURL $WebsiteURL -DomainSuffix $DomainSuffix -Country $Country -UpnDomain $UpnDomain -SecondaryEmailDomain $SecondaryEmailDomain