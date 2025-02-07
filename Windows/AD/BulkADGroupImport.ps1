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
    .\BulkADGroupImport.ps1 -CsvPath "C:\BulkADGroupImport.csv" -OuPath "OU=Security Groups,DC=contoso,DC=net"

.NOTES
    Autor: Eduardo Augusto Gomes(eduardo.agms@outlook.com.br)
    Data: 04/02/2025
    Versão: 2.2
        - Melhoria no log
        - Ajustes tecnicos
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

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$logFile = "C:\logs\BulkADGroupImport.log"

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

function Add-GroupsAndMembers {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$CsvPath,
        [string]$OuPath
    )

    try {
        $grupos = Import-Csv -Path $CsvPath -Encoding UTF8
        Write-Log "CSV importado com sucesso. Total de grupos a processar: $($grupos.Count)"
    }
    catch {
        Write-Log "Falha ao importar o CSV: $($_.Exception.Message)" -Level "ERROR"
        throw
    }

    $totalGroups = $grupos.Count
    $currentGroup = 0

    foreach ($grupo in $grupos) {
        $currentGroup++
        $percentComplete = ($currentGroup / $totalGroups) * 100
        Write-Progress -Activity "Processando grupos" -Status "$currentGroup de $totalGroups" -PercentComplete $percentComplete

        try {
            if (-not ($grupo.PSObject.Properties.Name -contains 'GroupName') -or -not ($grupo.PSObject.Properties.Name -contains 'MemberOf')) {
                Write-Log "Erro: As colunas 'GroupName' ou 'MemberOf' não foram encontradas no CSV." -Level "ERROR"
                continue
            }

            if (-not (Get-ADGroup -Filter "Name -eq '$($grupo.GroupName)'" -ErrorAction SilentlyContinue)) {
                if ($PSCmdlet.ShouldProcess($grupo.GroupName, "Criar grupo")) {
                    $newGroupParams = @{
                        Name       = $grupo.GroupName
                        GroupScope = 'Global'
                        Path       = $OuPath
                    }

                    New-ADGroup @newGroupParams -ErrorAction Stop
                    Write-Log "Grupo '$($grupo.GroupName)' criado em '$OuPath'."
                }
            }
            else {
                Write-Log "Grupo '$($grupo.GroupName)' já existe." -Level "WARNING"
            }

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
            Write-Log "Erro ao processar o grupo '$($grupo.GroupName)': $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

try {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Log "Este script requer PowerShell 7.0 ou superior. Versão atual: $($PSVersionTable.PSVersion)" -Level "ERROR"
        exit 1
    }

    Write-Log "Iniciando script de criação de grupos e adição de membros no AD."

    Import-ADModule
    Add-GroupsAndMembers -CsvPath $CsvPath -OuPath $OuPath

    Write-Log "Script concluído com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    throw
}
