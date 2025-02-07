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
    Autor: Eduardo Augusto Gomes(eduardo.agms@outlook.com.br)
    Data: 04/02/2025
    Versão: 3.1
        - Melhoria no log
        - Ajustes tecnicos

.LINK
    Repositório: https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
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

$logFile = "C:\logs\ADUserCreation.log"

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

function Import-UserCSV {
    param (
        [string]$Path,
        [string]$Delimiter,
        [string]$Encoding
    )

    if (-not (Test-Path -Path $Path)) {
        Write-Log "Arquivo CSV não encontrado: $Path" -Level "ERROR"
        throw "Arquivo CSV não encontrado: $Path"
    }

    try {
        $data = Import-Csv -Path $Path -Delimiter $Delimiter -Encoding $Encoding
        Write-Log "CSV importado com sucesso. Total de usuários a processar: $($data.Count)"
        return $data
    }
    catch {
        Write-Log "Falha ao importar o CSV: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Add-Users {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [array]$Users,
        [SecureString]$Password,
        [string]$DomainSuffix,
        [string]$UpnDomain,
        [string]$SecondaryEmailDomain
    )

    process {
        $totalUsers = $Users.Count
        $currentUser = 0

        foreach ($user in $Users) {
            $currentUser++
            $percentComplete = ($currentUser / $totalUsers) * 100
            Write-Progress -Activity "Criando usuários" -Status "$currentUser de $totalUsers" -PercentComplete $percentComplete

            try {
                if (-not $user.sAMAccountName) {
                    Write-Log "O campo sAMAccountName está vazio ou não definido. Verifique os dados do usuário." -Level "ERROR"
                    continue
                }

                $existingUser = Get-ADUser -Filter "SamAccountName -eq '$($user.sAMAccountName)'" -ErrorAction Stop

                if ($null -eq $existingUser) {
                    if ($PSCmdlet.ShouldProcess($user.sAMAccountName, "Criar usuário")) {
                        $userUpn = $UpnDomain ? "$($user.sAMAccountName)$UpnDomain" : "$($user.sAMAccountName)$DomainSuffix"

                        $newUserParams = @{
                            GivenName             = $user.givenName
                            Surname               = $user.sn
                            SamAccountName        = $user.sAMAccountName
                            DisplayName           = $user.namedisplayNamecn
                            Name                  = $user.namedisplayNamecn
                            Description           = $user.titledescription
                            Department            = $user.Department
                            Title                 = $user.titledescription
                            UserPrincipalName     = $userUpn
                            Path                  = $user.ou
                            AccountPassword       = $Password
                            Enabled               = $true
                            ChangePasswordAtLogon = $true
                        }

                        New-ADUser @newUserParams -ErrorAction Stop

                        $proxyAddresses = @("SMTP:$userUpn")
                        if ($SecondaryEmailDomain) {
                            $secondaryEmail = "$($user.sAMAccountName)$SecondaryEmailDomain"
                            $proxyAddresses += "smtp:$secondaryEmail"
                        }

                        Set-ADUser -Identity $user.sAMAccountName -Replace @{proxyAddresses = $proxyAddresses } -ErrorAction Stop

                        Write-Log "Usuário '$($user.sAMAccountName)' criado com sucesso com ProxyAddresses configurado."
                    }
                }
                else {
                    Write-Log "Usuário '$($user.sAMAccountName)' já existe. Pulando criação." -Level "WARNING"
                }
            }
            catch {
                Write-Log "Erro ao criar usuário '$($user.sAMAccountName)': $($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
}

function Update-Users {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [array]$Users,
        [string]$WebsiteURL,
        [string]$DomainSuffix,
        [string]$Country,
        [string]$UpnDomain,
        [string]$SecondaryEmailDomain
    )

    process {
        $totalUsers = $Users.Count
        $currentUser = 0

        foreach ($user in $Users) {
            $currentUser++
            $percentComplete = ($currentUser / $totalUsers) * 100
            Write-Progress -Activity "Atualizando usuários" -Status "$currentUser de $totalUsers" -PercentComplete $percentComplete

            try {
                $adUser = Get-ADUser -Identity $user.sAMAccountName -Properties * -ErrorAction Stop

                if ($adUser) {
                    if ($PSCmdlet.ShouldProcess($user.sAMAccountName, "Atualizar usuário")) {
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

                        $userUpn = $UpnDomain ? "$($user.sAMAccountName)$UpnDomain" : "$($user.sAMAccountName)$DomainSuffix"
                        $setParams['UserPrincipalName'] = $userUpn
                        $replaceParams['mail'] = $userUpn

                        $proxyAddresses = @("SMTP:$userUpn")
                        if ($SecondaryEmailDomain) {
                            $secondaryEmail = "$($user.sAMAccountName)$SecondaryEmailDomain"
                            $proxyAddresses += "smtp:$secondaryEmail"
                        }
                        $replaceParams['proxyAddresses'] = $proxyAddresses

                        Set-ADUser -Identity $adUser @setParams -ErrorAction Stop
                        Set-ADUser -Identity $adUser -Replace $replaceParams -ErrorAction Stop

                        Write-Log "Usuário '$($user.sAMAccountName)' atualizado com sucesso e ProxyAddresses configurado."
                    }
                }
                else {
                    Write-Log "Usuário '$($user.sAMAccountName)' não encontrado no AD. Pulando atualização." -Level "WARNING"
                }
            }
            catch {
                Write-Log "Erro ao atualizar usuário '$($user.sAMAccountName)': $($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
}

try {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Log "Este script requer PowerShell 7.0 ou superior. Versão atual: $($PSVersionTable.PSVersion)" -Level "ERROR"
        exit 1
    }
    Write-Log "Iniciando script de criação e atualização de usuários no AD."

    Import-ADModule
    $users = Import-UserCSV -Path $CsvPath -Delimiter $Delimiter -Encoding $Encoding
    $securePassword = ConvertTo-SecureString -String $DefaultPassword -AsPlainText -Force

    $users | Create-Users -Password $securePassword -DomainSuffix $DomainSuffix -UpnDomain $UpnDomain -SecondaryEmailDomain $SecondaryEmailDomain
    $users | Update-Users -WebsiteURL $WebsiteURL -DomainSuffix $DomainSuffix -Country $Country -UpnDomain $UpnDomain -SecondaryEmailDomain $SecondaryEmailDomain

    Write-Log "Script concluído com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}