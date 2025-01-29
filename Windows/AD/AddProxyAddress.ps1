<#
.SYNOPSIS
    Adiciona endereços de proxy para usuários no Active Directory a partir de um arquivo CSV.

.DESCRIPTION
    Este script importa dados de usuários a partir de um arquivo CSV, onde cada coluna corresponde a um atributo do usuário no Active Directory.
    Para cada usuário, são adicionados endereços SMTP adicionais aos endereços de proxy existentes.
    O script suporta caracteres especiais através da codificação UTF-8.

.PARAMETER CsvPath
    O caminho completo para o arquivo CSV que contém as informações dos usuários a serem processados.
    Exemplo: "C:\folder\smtp01.csv"

.PARAMETER Delimiter
    O delimitador utilizado no arquivo CSV. Padrão: ";"

.PARAMETER Encoding
    A codificação do arquivo CSV. Padrão: "UTF8".

.PARAMETER DomainSuffix
    O sufixo do domínio a ser utilizado para construir o endereço de e-mail dos usuários.
    Exemplo: "@contoso.local"

.EXAMPLE
    .\AddProxyAddresses.ps1 -CsvPath "C:\folder\smtp01.csv" -Delimiter ";" -Encoding "UTF8" -DomainSuffix "@contoso.local"

.NOTES
    Autor: Eduardo Augusto Gomes(eduardo.agms@outlook.com.br)
    Data: 29/01/2025
    Versão: 2.0
        Versão aprimorada com validações, logging, suporte a pipeline, tratamento de erros robusto e boas práticas do PowerShell 7.4.

.LINK
    Repositório: https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Diretório do arquivo CSV a ser importado.")]
    [string]$CsvPath,

    [Parameter(Mandatory = $false, HelpMessage = "Delimitador do CSV (; ou ,). Padrão: ';'.")]
    [string]$Delimiter = ";",

    [Parameter(Mandatory = $false, HelpMessage = "Codificação do arquivo CSV. Padrão: 'UTF8'.")]
    [string]$Encoding = "UTF8",

    [Parameter(Mandatory = $false, HelpMessage = "Sufixo do domínio para os endereços de e-mail. Exemplo: '@contoso.local'.")]
    [string]$DomainSuffix
)

# Configurações iniciais
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$logFile = "C:\logs\AddProxyAddresses.log"

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

# Função para importar o CSV
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
        Write-Log "Falha ao importar o CSV: $_" -Level "ERROR"
        throw
    }
}

# Função para adicionar endereços de proxy
function Add-ProxyAddresses {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [array]$Users,
        [string]$DomainSuffix
    )

    process {
        $totalUsers = $Users.Count
        $currentUser = 0

        foreach ($user in $Users) {
            $currentUser++
            $percentComplete = ($currentUser / $totalUsers) * 100
            Write-Progress -Activity "Adicionando endereços de proxy" -Status "$currentUser de $totalUsers" -PercentComplete $percentComplete

            try {
                if (-not $user.user) {
                    Write-Log "O campo 'user' está vazio ou não definido. Verifique os dados do usuário." -Level "ERROR"
                    continue
                }

                if ($PSCmdlet.ShouldProcess($user.user, "Adicionar endereços de proxy")) {
                    $SMTP1 = "SMTP:$($user.smtp)$DomainSuffix"
                    $SMTP2 = "smtp:$($user.smtp1)$DomainSuffix"

                    $adUser = Get-ADUser -Identity $user.user -Properties ProxyAddresses -ErrorAction Stop

                    if ($adUser) {
                        $proxyAddresses = $adUser.ProxyAddresses
                        $proxyAddresses += $SMTP1
                        $proxyAddresses += $SMTP2

                        Set-ADUser -Identity $user.user -Replace @{ProxyAddresses = $proxyAddresses } -ErrorAction Stop

                        Write-Log "Endereços de proxy adicionados para o usuário '$($user.user)': $SMTP1, $SMTP2"
                    }
                    else {
                        Write-Log "Usuário '$($user.user)' não encontrado no Active Directory. Ignorando." -Level "WARNING"
                    }
                }
            }
            catch {
                Write-Log "Erro ao adicionar endereços de proxy para o usuário '$($user.user)': $_" -Level "ERROR"
            }
        }
    }
}

# Início do script
try {
    Write-Log "Iniciando script de adição de endereços de proxy no AD."

    Import-ADModule
    $usuarios = Import-UserCSV -Path $CsvPath -Delimiter $Delimiter -Encoding $Encoding

    $usuarios | Add-ProxyAddresses -DomainSuffix $DomainSuffix

    Write-Log "Script concluído com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $_" -Level "ERROR"
    throw
}