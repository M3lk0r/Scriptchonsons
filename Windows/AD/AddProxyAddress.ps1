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
    Autor: eduardo.agms@outlook.com.br
    Data: 28/01/2025
    Versão: 1.2
        Força output : UTF-8
        
.LINK
    Repositório: https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding()]
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

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Verbose "Módulo ActiveDirectory importado com sucesso."
} catch {
    Write-Error "Falha ao importar o módulo ActiveDirectory: $_"
    exit 1
}

try {
    $usuarios = Import-Csv -Path $CsvPath -Delimiter $Delimiter -Encoding $Encoding
    Write-Host "CSV importado com sucesso. Total de usuários a processar: $($usuarios.Count)" -ForegroundColor Green
} catch {
    Write-Error "Falha ao importar o CSV: $_"
    exit 1
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$SMTP1Prefix = "SMTP:"
$SMTP2Prefix = "smtp:"

function Add-ProxyAddresses {
    foreach ($user in $usuarios) {
        try {
            $SMTP1 = "$SMTP1Prefix$user.smtp$DomainSuffix"
            $SMTP2 = "$SMTP2Prefix$user.smtp1$DomainSuffix"

            $adUser = Get-ADUser -Identity $user.user -Properties ProxyAddresses

            if ($adUser) {
                $proxyAddresses = $adUser.ProxyAddresses
                $proxyAddresses += $SMTP1
                $proxyAddresses += $SMTP2

                Set-ADUser -Identity $user.user -Replace @{ProxyAddresses = $proxyAddresses}

                Write-Host "Endereços de proxy adicionados para o usuário $($user.user): $SMTP1, $SMTP2" -ForegroundColor Cyan
            } else {
                Write-Warning "Usuário $($user.user) não encontrado no Active Directory. Ignorando."
            }
        } catch {
            Write-Warning "Erro ao adicionar endereços de proxy para o usuário $($user.user): $_"
        }
    }
}

Add-ProxyAddresses