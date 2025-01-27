<#
.SYNOPSIS
    Exporta usuários de uma Unidade Organizacional (OU) do Active Directory para um arquivo CSV.

.DESCRIPTION
    Este script conecta-se ao Active Directory, busca todos os usuários dentro de uma OU especificada,
    e exporta informações selecionadas (distinguishedName, cn, sn, givenName, sAMAccountName) para
    um arquivo CSV em um diretório definido pelo usuário.

.PARAMETER OU
    O Distinguished Name (DN) da Unidade Organizacional (OU) que será consultada no Active Directory.
    Exemplo: "OU=Usuarios,OU=Departamentos,DC=empresa,DC=com"

.PARAMETER DiretorioExportacao
    O caminho do diretório onde o arquivo CSV será salvo. Se o diretório não existir, ele será criado.

.PARAMETER NomeArquivoCSV
    O nome do arquivo CSV de saída. Por padrão, "Usuarios_AD.csv".

.EXAMPLE
    .\ExportarUsuariosAD.ps1 -OU "OU=Usuarios,OU=Departamentos,DC=empresa,DC=com" -DiretorioExportacao "C:\Exportacoes" -NomeArquivoCSV "Usuarios_AD.csv"

.NOTES
    Autor: eduardo.agms@outlook.com.br
    Data: 27/01/2025
    Versão: 1.0
        Versão inicial do script.

.LINK
    https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Distinguished Name (DN) da Unidade Organizacional (OU) do AD.")]
    [string]$OU,

    [Parameter(Mandatory = $true, HelpMessage = "Diretório onde o arquivo CSV será salvo.")]
    [string]$DiretorioExportacao,

    [Parameter(Mandatory = $false, HelpMessage = "Nome do arquivo CSV de saída.")]
    [string]$NomeArquivoCSV = "Usuarios_AD.csv"
)

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Verbose "Módulo ActiveDirectory importado com sucesso."
}
catch {
    Write-Error "Falha ao importar o módulo ActiveDirectory: $_"
    exit 1
}

$CaminhoCompletoCSV = Join-Path -Path $DiretorioExportacao -ChildPath $NomeArquivoCSV

if (-not (Test-Path -Path $DiretorioExportacao)) {
    try {
        New-Item -Path $DiretorioExportacao -ItemType Directory -Force | Out-Null
        Write-Host "Diretório criado: $DiretorioExportacao" -ForegroundColor Green
    }
    catch {
        Write-Error "Não foi possível criar o diretório de exportação: $_"
        exit 1
    }
}
else {
    Write-Verbose "Diretório de exportação existente: $DiretorioExportacao"
}

try {
    Write-Verbose "Iniciando a recuperação de usuários do AD na OU: $OU"
    $Usuarios = Get-ADUser -Filter * `
                         -SearchBase $OU `
                         -Properties distinguishedName, cn, sn, givenName, sAMAccountName -ErrorAction Stop
    Write-Verbose "Recuperação de usuários concluída. Total de usuários encontrados: $($Usuarios.Count)"
}
catch {
    Write-Error "Erro ao recuperar usuários do AD: $_"
    exit 1
}

$DadosUsuarios = $Usuarios | Select-Object `
    distinguishedName, `
    cn, `
    sn, `
    givenName, `
    sAMAccountName

try {
    $DadosUsuarios | Export-Csv -Path $CaminhoCompletoCSV -NoTypeInformation -Encoding UTF8
    Write-Host "Exportação concluída com sucesso! Arquivo salvo em: $CaminhoCompletoCSV" -ForegroundColor Cyan
}
catch {
    Write-Error "Erro ao exportar para CSV: $_"
    exit 1
}