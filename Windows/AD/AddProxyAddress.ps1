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
    Data: 04/02/2025
    Versão: 2.1
        - Melhoria no log
        - Ajustes tecnicos

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

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$logFile = "C:\logs\AddProxyAddresses.log"

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

        Write-Output $logEntry | Write-Host -ForegroundColor $color
    }
    catch {
        Write-Host "Erro ao escrever no log: $_" -ForegroundColor Red
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
                Write-Log "Erro ao adicionar endereços de proxy para o usuário '$($user.user)': $($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
}

try {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Log "Este script requer PowerShell 7.0 ou superior. Versão atual: $($PSVersionTable.PSVersion)" -Level "ERROR"
        exit 1
    }
    
    Write-Log "Iniciando script de adição de endereços de proxy no AD."

    Import-ADModule
    $usuarios = Import-UserCSV -Path $CsvPath -Delimiter $Delimiter -Encoding $Encoding

    $usuarios | Add-ProxyAddresses -DomainSuffix $DomainSuffix

    Write-Log "Script concluído com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}