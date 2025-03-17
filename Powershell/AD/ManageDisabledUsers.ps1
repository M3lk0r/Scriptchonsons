<#
.SYNOPSIS
    Gerencia usuários no Active Directory, alterando o grupo primário, removendo outros grupos, movendo para uma OU específica e renomeando.

.DESCRIPTION
    Este script permite processar usuários a partir de um arquivo CSV contendo sAMAccountName ou DistinguishedName, ou passar um único usuário diretamente.
    O script altera o grupo primário, remove todos os outros grupos, move os usuários para uma OU específica e renomeia os usuários adicionando "Desligado - " antes do nome.

.PARAMETER UserList
    Lista de sAMAccountNames ou DistinguishedNames dos usuários a serem processados.

.PARAMETER CsvPath
    Caminho para o arquivo CSV contendo os usuários a serem processados. O CSV deve ter uma coluna chamada "User" com sAMAccountName ou DistinguishedName.

.PARAMETER PrimaryGroup
    Nome do grupo que será definido como grupo primário dos usuários.

.PARAMETER MoveToOU
    Caminho da Unidade Organizacional (OU) de destino para onde os usuários serão movidos.

.EXAMPLE
    # Processar um único usuário
    .\ManageDisabledUsers.ps1 -UserList "user1" -PrimaryGroup "Disabled Users" -MoveToOU "OU=Disabled Users,DC=domain,DC=com"

    # Processar múltiplos usuários via CSV
    .\ManageDisabledUsers.ps1 -CsvPath "C:\users.csv" -PrimaryGroup "Disabled Users" -MoveToOU "OU=Disabled Users,DC=domain,DC=com"

.NOTES
    Autor: Eduardo Augusto Gomes(eduardo.agms@outlook.com.br)
    Data: 06/02/2025
    Versão: 1.3
        - Adicionado suporte para renomear o givenName.
        - Processo de definição do grupo primário em 3 etapas.
        - Verificação para evitar duplicação de "Desligado - " no nome.

.LINK
    https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Lista de sAMAccountNames ou DistinguishedNames dos usuários a serem processados.")]
    [string[]]$UserList,

    [Parameter(Mandatory = $false, HelpMessage = "Caminho para o arquivo CSV contendo os usuários a serem processados.")]
    [string]$CsvPath,

    [Parameter(Mandatory = $true, HelpMessage = "Nome do grupo que será definido como grupo primário dos usuários.")]
    [string]$PrimaryGroup,

    [Parameter(Mandatory = $true, HelpMessage = "Caminho da Unidade Organizacional (OU) de destino para onde os usuários serão movidos.")]
    [string]$MoveToOU
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$logFile = "C:\logs\ManageDisabledUsers.log"

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$Level] $Message"

        $logDir = [System.IO.Path]::GetDirectoryName($logFile)
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        $logEntry | Out-File -FilePath $logFile -Encoding UTF8 -Append

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

function Get-UserIdentity {
    param (
        [string]$UserIdentifier
    )

    try {
        $user = Get-ADUser -Identity $UserIdentifier -ErrorAction SilentlyContinue
        if ($user) {
            return $user
        }

        $user = Get-ADUser -Identity $UserIdentifier -ErrorAction SilentlyContinue
        if ($user) {
            return $user
        }

        Write-Log "Usuário '$UserIdentifier' não encontrado." -Level "ERROR"
        return $null
    }
    catch {
        Write-Log "Erro ao buscar o usuário '$UserIdentifier': $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Add-UserToGroup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$SamAccountName,
        [string]$GroupName
    )

    try {
        if ($PSCmdlet.ShouldProcess($SamAccountName, "Adicionar ao grupo '$GroupName'")) {
            Add-ADGroupMember -Identity $GroupName -Members $SamAccountName -ErrorAction Stop
            Write-Log "Usuário '$SamAccountName' adicionado ao grupo '$GroupName'."
        }
    }
    catch {
        Write-Log "Falha ao adicionar o usuário '$SamAccountName' ao grupo '$GroupName': $($_.Exception.Message)" -Level "ERROR"
    }
}

function Set-PrimaryGroup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$SamAccountName,
        [string]$PrimaryGroup
    )

    try {
        $group = Get-ADGroup -Identity $PrimaryGroup -Properties PrimaryGroupToken -ErrorAction Stop
        $primaryGroupID = [string]$group.PrimaryGroupToken

        if ($PSCmdlet.ShouldProcess($SamAccountName, "Definir grupo primário como '$PrimaryGroup'")) {
            Set-ADUser -Identity $SamAccountName -Replace @{primaryGroupID = $primaryGroupID } -ErrorAction Stop
            Write-Log "Grupo principal definido como '$PrimaryGroup' para o usuário '$SamAccountName'."
        }
    }
    catch {
        Write-Log "Falha ao definir o grupo principal para o usuário '$SamAccountName': $($_.Exception.Message)" -Level "ERROR"
    }
}

function Remove-OtherGroups {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$SamAccountName,
        [string]$PrimaryGroup
    )

    try {
        $user = Get-ADUser -Identity $SamAccountName -Properties MemberOf -ErrorAction Stop
        $groupsToRemove = $user.MemberOf | Where-Object { $_ -ne (Get-ADGroup -Identity $PrimaryGroup).DistinguishedName }

        foreach ($groupDN in $groupsToRemove) {
            if ($PSCmdlet.ShouldProcess($SamAccountName, "Remover do grupo '$groupDN'")) {
                Remove-ADGroupMember -Identity $groupDN -Members $SamAccountName -Confirm:$false -ErrorAction Stop
                Write-Log "Usuário '$SamAccountName' removido do grupo '$groupDN'."
            }
        }
    }
    catch {
        Write-Log "Falha ao remover grupos do usuário '$SamAccountName': $($_.Exception.Message)" -Level "ERROR"
    }
}

function Move-UserToOU {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$SamAccountName,
        [string]$TargetOU
    )

    try {
        if ($PSCmdlet.ShouldProcess($SamAccountName, "Mover para a OU '$TargetOU'")) {
            Move-ADObject -Identity (Get-ADUser -Identity $SamAccountName).DistinguishedName -TargetPath $TargetOU -ErrorAction Stop
            Write-Log "Usuário '$SamAccountName' movido para '$TargetOU'."
        }
    }
    catch {
        Write-Log "Falha ao mover o usuário '$SamAccountName' para '$TargetOU': $($_.Exception.Message)" -Level "ERROR"
    }
}

function Rename-User {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$SamAccountName
    )

    try {
        $user = Get-ADUser -Identity $SamAccountName -Properties DisplayName, GivenName, CN -ErrorAction Stop

        if (-not $user.CN.StartsWith("Desligado - ")) {
            $newCN = "Desligado - " + $user.CN
            $newGivenName = "Desligado - " + $user.GivenName
            $newDisplayName = "Desligado - " + $user.DisplayName

            if ($PSCmdlet.ShouldProcess($SamAccountName, "Renomear para '$newCN', '$newGivenName' e '$newDisplayName'")) {
                Rename-ADObject -Identity $user.DistinguishedName -NewName $newCN -ErrorAction Stop
                Set-ADUser -Identity $SamAccountName -GivenName $newGivenName -DisplayName $newDisplayName -ErrorAction Stop
                Write-Log "Usuário '$SamAccountName' renomeado para '$newCN', '$newGivenName' e '$newDisplayName'."
            }
        }
        else {
            Write-Log "Usuário '$SamAccountName' já possui 'Desligado - ' no nome. Ignorando renomeação." -Level "WARNING"
        }
    }
    catch {
        Write-Log "Falha ao renomear o usuário '$SamAccountName': $($_.Exception.Message)" -Level "ERROR"
    }
}

function Disable-User {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string]$SamAccountName
    )
    
    try {
        if (-not $SamAccountName) {
            throw "O parâmetro 'SamAccountName' não pode estar vazio."
        }

        $user = Get-ADUser -Identity $SamAccountName -ErrorAction Stop
        
        if ($user) {
            if ($PSCmdlet.ShouldProcess($SamAccountName, "Desabilitar usuário")) {
                Disable-ADAccount -Identity $SamAccountName -ErrorAction Stop
                Write-Log "Usuário '$SamAccountName' desabilitado com sucesso." -Level "INFO"
            }
        } else {
            Write-Log "Usuário '$SamAccountName' não encontrado." -Level "WARNING"
        }
    } catch {
        Write-Log "Falha ao desabilitar o usuário '$SamAccountName': $($_.Exception.Message)" -Level "ERROR"
    }
}

function Invoke-UserProcessing {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [string[]]$UserList,
        [string]$PrimaryGroup,
        [string]$MoveToOU
    )

    $totalUsers = $UserList.Count
    $currentUser = 0

    foreach ($userIdentifier in $UserList) {
        $currentUser++
        $percentComplete = ($currentUser / $totalUsers) * 100
        Write-Progress -Activity "Processando usuários" -Status "$currentUser de $totalUsers" -PercentComplete $percentComplete

        $user = Get-UserIdentity -UserIdentifier $userIdentifier
        if ($user) {
            Add-UserToGroup -SamAccountName $user.SamAccountName -GroupName $PrimaryGroup
            Set-PrimaryGroup -SamAccountName $user.SamAccountName -PrimaryGroup $PrimaryGroup
            Remove-OtherGroups -SamAccountName $user.SamAccountName -PrimaryGroup $PrimaryGroup
            Move-UserToOU -SamAccountName $user.SamAccountName -TargetOU $MoveToOU
            Rename-User -SamAccountName $user.SamAccountName
            Disable-User -SamAccountName $user.SamAccountName
        }
    }
}

try {
    Write-Log "Iniciando script de gerenciamento de usuários desativados no AD."

    Import-ADModule

    if ($CsvPath) {
        if (-not (Test-Path $CsvPath)) {
            Write-Log "Arquivo CSV não encontrado: $CsvPath" -Level "ERROR"
            exit 1
        }

        $users = Import-Csv -Path $CsvPath
        $UserList = $users.User
    }
    elseif (-not $UserList) {
        Write-Log "Nenhum usuário ou CSV fornecido. Use -UserList ou -CsvPath." -Level "ERROR"
        exit 1
    }

    Invoke-UserProcessing -UserList $UserList -PrimaryGroup $PrimaryGroup -MoveToOU $MoveToOU

    Write-Log "Script concluído com sucesso."
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}