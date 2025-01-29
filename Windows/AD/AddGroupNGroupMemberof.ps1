<#
.SYNOPSIS
    Cria grupos no Active Directory a partir de um arquivo CSV e adiciona grupos existentes como membros de outros grupos.

.DESCRIPTION
    Este script PowerShell importa um arquivo CSV contendo informações sobre grupos e seus respectivos membros no Active Directory. 
    Ele cria os grupos, caso não existam, e os adiciona a outros grupos, conforme especificado na coluna 'MemberOf' do CSV. 
    O script também exibe informações de status durante a execução.

.PARAMETER CsvPath
    Caminho para o arquivo CSV contendo os grupos e seus membros.

.PARAMETER OuPath
    Caminho para a Unidade Organizacional (OU) onde os grupos serão criados no Active Directory.

.EXAMPLE
    .\AddGroupNGroupMemberof.ps1 -CsvPath "C:\AddGroupNGroupMemberof.csv" -OuPath "OU=File Server,OU=Security Groups,DC=agripecas,DC=net"

.NOTES
    Autor: Eduardo Augusto Gomes(eduardo.agms@outlook.com.br)
    Data: 29/01/2025
    Versão: 2.1
        Versão aprimorada com validações, logging, suporte a pipeline, tratamento de erros robusto e boas práticas do PowerShell 7.5.

.LINK
    https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Caminho para o arquivo CSV contendo os grupos e seus membros.")]
    [string]$CsvPath,

    [Parameter(Mandatory = $true, HelpMessage = "Caminho para a Unidade Organizacional (OU) onde os grupos serão criados no Active Directory.")]
    [string]$OuPath
)

# Verificação de versão do PowerShell
if ($PSVersionTable.PSVersion -lt [Version]"7.0") {
    Write-Host "Este script requer PowerShell 7.0 ou superior. Versão atual: $($PSVersionTable.PSVersion)" -ForegroundColor Red
    exit 1
}

# Configurações iniciais
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$logFile = "C:\logs\AddGroupNGroupMemberof.log"

# Função para escrever logs
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Exibe na tela
    Write-Host $logEntry

    # Salva no arquivo de log
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

# Função para criar grupos e adicionar membros
function Add-GroupsAndMembers {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$CsvPath,
        [string]$OuPath
    )

    try {
        # Importar o CSV
        $grupos = Import-Csv -Path $CsvPath -Encoding UTF8
        Write-Log "CSV importado com sucesso. Total de grupos a processar: $($grupos.Count)"
    }
    catch {
        Write-Log "Falha ao importar o CSV: $_" -Level "ERROR"
        throw
    }

    $totalGroups = $grupos.Count
    $currentGroup = 0

    foreach ($grupo in $grupos) {
        $currentGroup++
        $percentComplete = ($currentGroup / $totalGroups) * 100
        Write-Progress -Activity "Processando grupos" -Status "$currentGroup de $totalGroups" -PercentComplete $percentComplete

        try {
            # Verificar se as propriedades existem
            if (-not ($grupo.PSObject.Properties.Name -contains 'GroupName') -or -not ($grupo.PSObject.Properties.Name -contains 'MemberOf')) {
                Write-Log "Erro: As colunas 'GroupName' ou 'MemberOf' não foram encontradas no CSV." -Level "ERROR"
                continue
            }

            # Criar o grupo se ele não existir
            if (-not (Get-ADGroup -Filter "Name -eq '$($grupo.GroupName)'" -ErrorAction SilentlyContinue)) {
                if ($PSCmdlet.ShouldProcess($grupo.GroupName, "Criar grupo")) {
                    $newGroupParams = @{
                        Name        = $grupo.GroupName
                        GroupScope  = 'Global'
                        Path        = $OuPath
                    }

                    New-ADGroup @newGroupParams -ErrorAction Stop
                    Write-Log "Grupo '$($grupo.GroupName)' criado em '$OuPath'."
                }
            }
            else {
                Write-Log "Grupo '$($grupo.GroupName)' já existe." -Level "WARNING"
            }

            # Adicionar o grupo como membro do grupo especificado na coluna 'MemberOf'
            if (Get-ADGroup -Filter "Name -eq '$($grupo.MemberOf)'" -ErrorAction SilentlyContinue) {
                if ($PSCmdlet.ShouldProcess($grupo.MemberOf, "Adicionar membro '$($grupo.GroupName)'")) {
                    Add-ADGroupMember -Identity $grupo.MemberOf -Members $grupo.GroupName -ErrorAction Stop
                    Write-Log "Grupo '$($grupo.GroupName)' adicionado ao grupo '$($grupo.MemberOf)'."
                }
            }
            else {
                Write-Log "Grupo '$($grupo.MemberOf)' não encontrado. Não foi possível adicionar '$($grupo.GroupName)'." -Level "WARNING"
            }
        }
        catch {
            Write-Log "Erro ao processar o grupo '$($grupo.GroupName)': $_" -Level "ERROR"
        }
    }
}

# Início do script
try {
    Write-Log "Iniciando script de criação de grupos e adição de membros no AD."

    Import-ADModule
    Add-GroupsAndMembers -CsvPath $CsvPath -OuPath $OuPath

    Write-Log "Script concluído com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $_" -Level "ERROR"
    throw
}
