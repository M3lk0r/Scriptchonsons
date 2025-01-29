<#
.SYNOPSIS
    Atualiza a política de senha para usuários no Active Directory a partir de um arquivo CSV.

.DESCRIPTION
    Este script importa um arquivo CSV contendo nomes de usuários e desativa a opção "PasswordNeverExpires" para cada usuário listado.
    O script suporta tratamento de erros, logging e feedback visual durante a execução.

.PARAMETER CsvPath
    Caminho para o arquivo CSV contendo os nomes dos usuários.

.PARAMETER Delimiter
    Delimitador utilizado no arquivo CSV. Padrão: ";"

.PARAMETER Encoding
    Codificação do arquivo CSV. Padrão: "Default"

.EXAMPLE
    .\Update-PasswordPolicy.ps1 -CsvPath "C:\Users\adm.gomes\Desktop\passwordnerver.csv" -Delimiter ";" -Encoding "Default"

.NOTES
    Autor: Eduardo Augusto Gomes(eduardo.agms@outlook.com.br)
    Data: 29/01/2025
    Versão: 2.0
        Versão aprimorada com validações, logging, suporte a pipeline, tratamento de erros robusto e boas práticas do PowerShell 7.4.

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
    [string]$Encoding = "Default"
)

# Configurações iniciais
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$logFile = "C:\logs\UpdatePasswordPolicy.log"

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

# Função para atualizar a política de senha dos usuários
function Update-PasswordPolicy {
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
                    # Obtém o usuário do AD
                    $adUser = Get-ADUser -Identity $user.Username -Properties PasswordNeverExpires -ErrorAction Stop

                    # Verifica se a configuração precisa ser atualizada
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
                Write-Log "Falha ao atualizar a política de senha para o usuário '$($user.Username)': $_" -Level "ERROR"
            }
        }
    }
}

# Início do script
try {
    Write-Log "Iniciando script de atualização de política de senha no AD."

    Import-ADModule
    $csvData = Import-UserCSV -Path $CsvPath -Delimiter $Delimiter -Encoding $Encoding

    $csvData | Update-PasswordPolicy

    Write-Log "Script concluído com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $_" -Level "ERROR"
    throw
}