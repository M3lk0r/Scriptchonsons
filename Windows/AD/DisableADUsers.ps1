<#
.SYNOPSIS
    Desabilita usuários no Active Directory a partir de um arquivo CSV.

.DESCRIPTION
    Este script importa dados de usuários a partir de um arquivo CSV, onde cada linha contém o `sAMAccountName` de cada usuário no Active Directory.
    O script desabilita os usuários cujos `sAMAccountName` estão presentes no arquivo CSV.
    O script suporta caracteres especiais através da codificação UTF-8.

.PARAMETER CsvPath
    O caminho completo para o arquivo CSV que contém os `sAMAccountName` dos usuários a serem desabilitados.
    Exemplo: "C:\csv\users2disable.csv"

.PARAMETER Delimiter
    O delimitador utilizado no arquivo CSV. O padrão é ";" para arquivos CSV com dados separados por ponto e vírgula.

.PARAMETER Encoding
    A codificação do arquivo CSV. Por padrão, é definido como "UTF8" para suportar caracteres especiais.

.EXAMPLE
    .\DisableADUsers.ps1 -CsvPath "C:\csv\users2disable.csv" -Delimiter ";" -Encoding "UTF8"

.NOTES
    Autor: Eduardo Augusto Gomes(eduardo.agms@outlook.com.br)
    Data: 29/01/2025
    Versão: 1.1
        Força output : UTF-8
    
.LINK
    Repositório: https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Caminho completo para o arquivo CSV com os sAMAccountName dos usuários a serem desabilitados.")]
    [string]$CsvPath,

    [Parameter(Mandatory = $false, HelpMessage = "Delimitação do CSV (, ou ;), padrão é (;).")]
    [string]$Delimiter = ";",

    [Parameter(Mandatory = $false, HelpMessage = "Codificação do arquivo CSV, padrão é UTF8.")]
    [string]$Encoding = "UTF8"
)

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Verbose "Módulo ActiveDirectory importado com sucesso."
}
catch {
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
function Disable-ADUserAccount {
    param (
        [string]$SamAccountName
    )

    try {
        $user = Get-ADUser -Identity $SamAccountName -Properties Enabled

        if ($user) {
            if ($user.Enabled -eq $true) {
                Disable-ADAccount -Identity $user
                Write-Host "Usuário $($SamAccountName) desabilitado com sucesso." -ForegroundColor Cyan
            } else {
                Write-Host "Usuário $($SamAccountName) já está desabilitado." -ForegroundColor Yellow
            }
        } else {
            Write-Warning "Usuário $($SamAccountName) não encontrado no Active Directory."
        }
    } catch {
        Write-Warning "Erro ao tentar desabilitar o usuário $($SamAccountName): $_"
    }
}

foreach ($usuario in $usuarios) {
    Disable-ADUserAccount -SamAccountName $usuario.sAMAccountName
}
