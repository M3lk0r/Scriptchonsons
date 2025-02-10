<#
.SYNOPSIS
    Atualiza a política de senha para usuários no Active Directory a partir de um arquivo CSV.

.DESCRIPTION
    Este script importa um arquivo CSV contendo sAMAccountName e desativa a opção "PasswordNeverExpires" para cada usuário listado.
    O script suporta tratamento de erros, logging e feedback visual durante a execução.

.PARAMETER CsvPath
    Caminho para o arquivo CSV contendo os nomes dos usuários.

.PARAMETER Delimiter
    Delimitador utilizado no arquivo CSV. Padrão: ";"

.PARAMETER Encoding
    Codificação do arquivo CSV. Padrão: "UTF8"

.EXAMPLE
    .\UpdatePasswordPolicy.ps1 -CsvPath "C:\passwordnerver.csv" -Delimiter ";" -Encoding "UTF8"

.NOTES
    Autor: Eduardo Augusto Gomes(eduardo.agms@outlook.com.br)
    Data: 06/02/2025
    Versão: 2.1
        - Suporte otimizado para PowerShell 7.5
        - Melhor tratamento de erros
        - Aprimoramento no logging

.LINK
    https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Caminho para o arquivo CSV contendo os nomes dos usuários.")]
    [string]$CsvPath,

    [Parameter(Mandatory = $false, HelpMessage = "Delimitador utilizado no arquivo CSV. Padrão: ';'")]
    [string]$Delimiter = ";",

    [Parameter(Mandatory = $false, HelpMessage = "Codificação do arquivo CSV. Padrão: 'Default'")]
    [string]$Encoding = "UTF8"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$logFile = "C:\logs\UpdatePasswordPolicy.log"

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

function UpdatePasswordPolicy {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [array]$Users
    )

    process {
        $totalUsers = $Users.Count
        $currentUser = 0

        foreach ($user in $Users) {
            $currentUser++
            $percentComplete = ($currentUser / $totalUsers) * 100
            Write-Progress -Activity "Atualizando política de senha" -Status "$currentUser de $totalUsers" -PercentComplete $percentComplete

            try {
                if (-not $user.Username) {
                    Write-Log "O campo 'Username' está vazio ou não definido. Verifique os dados do usuário." -Level "ERROR"
                    continue
                }

                if ($PSCmdlet.ShouldProcess($user.Username, "Atualizar política de senha")) {
                    $adUser = Get-ADUser -Identity $user.Username -Properties PasswordNeverExpires -ErrorAction Stop

                    if ($adUser.PasswordNeverExpires) {
                        Set-ADUser -Identity $user.Username -PasswordNeverExpires $false -ErrorAction Stop
                        Write-Log "Política de senha atualizada para o usuário '$($user.Username)'."
                    }
                    else {
                        Write-Log "Nenhuma alteração necessária para o usuário '$($user.Username)'." -Level "INFO"
                    }
                }
            }
            catch {
                Write-Log "Falha ao atualizar a política de senha para o usuário '$($user.Username)': $($_.Exception.Message)" -Level "ERROR"
            }
        }
    }
}

try {
    Write-Log "Iniciando script de atualização de política de senha no AD."

    Get-PSVersion

    Import-ADModule
 
    $csvData = Import-UserCSV -Path $CsvPath -Delimiter $Delimiter -Encoding $Encoding

    $csvData | UpdatePasswordPolicy

    Write-Log "Script concluído com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}