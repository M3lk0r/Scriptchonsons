<#
.SYNOPSIS
    Realiza a cópia de arquivos de um diretório de origem para um diretório de destino, verificando a integridade dos arquivos e removendo arquivos antigos da origem.

.DESCRIPTION
    Este script copia arquivos de um diretório de origem para um diretório de destino, verificando a integridade dos arquivos através de hash SHA256.
    Após a cópia, arquivos na origem que são mais antigos que 7 dias e já estão validados no destino são removidos.

.PARAMETER Origem
    Caminho do diretório de origem.

.PARAMETER Destino
    Caminho do diretório de destino.

.PARAMETER LogDir
    Caminho do diretório de logs. Padrão C:\Logs.

.EXAMPLE
    .\CopyFilesWithIntegrityCheck.ps1 -Origem "C:\Origem" -Destino "C:\Destino" -LogDir "C:\Logs"

.NOTES
    Autor: Eduardo Augusto Gomes (eduardo.agms@outlook.com.br)
    Data: 24/02/2025
    Versão: 2.2
        - Melhorias gerais(mudei muita coisa hehe)

.LINK
    https://github.com/M3lk0r/Scriptchonsons
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Caminho do diretório de origem.")]
    [ValidateNotNullOrEmpty()]
    [string]$Origem,

    [Parameter(Mandatory = $true, HelpMessage = "Caminho do diretório de destino.")]
    [ValidateNotNullOrEmpty()]
    [string]$Destino,

    [Parameter(Mandatory = $false, HelpMessage = "Caminho do diretório de logs.")]
    [string]$LogDir = "C:\Logs"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$DataHora = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFile = Join-Path -Path $LogDir -ChildPath "Copia_Arquivos_$DataHora.log"

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

function Get-FileHashValue {
    param (
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    try {
        return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
    }
    catch {
        Write-Log "Falha ao obter hash do arquivo: $FilePath. Erro: $($_.Exception.Message)" -Level "ERROR"
        throw $_
    }
}

function Get-RelativePath {
    param (
        [Parameter(Mandatory)]
        [string]$BasePath,

        [Parameter(Mandatory)]
        [string]$FullPath
    )

    try {
        $baseUri = New-Object -TypeName System.Uri -ArgumentList $BasePath
        $fullUri = New-Object -TypeName System.Uri -ArgumentList $FullPath
        return $baseUri.MakeRelativeUri($fullUri).ToString().Replace("/", "\")
    }
    catch {
        Write-Log "Falha ao calcular caminho relativo. Erro: $($_.Exception.Message)" -Level "ERROR"
        throw $_
    }
}

function Copy-FileWithIntegrityCheck {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    try {
        $relativoPath = Get-RelativePath -BasePath $Origem -FullPath $SourcePath

        $destinoDir = [System.IO.Path]::GetDirectoryName($DestinationPath)

        if (-not (Test-Path -Path $destinoDir)) {
            if ($PSCmdlet.ShouldProcess($destinoDir, "Criar diretório para $relativoPath")) {
                New-Item -ItemType Directory -Path $destinoDir -Force | Out-Null
                Write-Log "Diretório criado: $destinoDir"
            }
        }

        if (Test-Path -Path $DestinationPath) {
            $hashOrigem = Get-FileHashValue -FilePath $SourcePath
            $hashDestino = Get-FileHashValue -FilePath $DestinationPath

            if ($hashOrigem -eq $hashDestino) {
                Write-Log "Arquivo já existente e válido: $relativoPath. Nenhuma ação necessária."
            } else {
                Write-Log "Hash divergente para $relativoPath. Substituindo arquivo."
                if ($PSCmdlet.ShouldProcess($DestinationPath, "Substituir arquivo $relativoPath")) {
                    Copy-Item -Path $SourcePath -Destination $DestinationPath -Force -ErrorAction Stop
                    Write-Log "Arquivo substituído: $relativoPath"
                }
            }
        } else {
            Write-Log "Arquivo não encontrado no destino: $relativoPath. Realizando cópia."
            if ($PSCmdlet.ShouldProcess($DestinationPath, "Copiar arquivo $relativoPath")) {
                Copy-Item -Path $SourcePath -Destination $DestinationPath -Force -ErrorAction Stop
                Write-Log "Arquivo copiado: $relativoPath"
            }
        }
    }
    catch {
        Write-Log "Erro ao copiar arquivo $SourcePath para $($DestinationPath): $_" -Level "ERROR"
        throw $_
    }
}

function Remove-OldFilesFromSource {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$OrigemPath,

        [Parameter(Mandatory)]
        [string]$DestinoPathBase
    )

    try {
        $relativoPath = Get-RelativePath -BasePath $OrigemPath -FullPath $SourcePath

        $destinoPath = Join-Path -Path $DestinoPathBase -ChildPath $relativoPath

        if (Test-Path -Path $destinoPath) {
            $hashOrigem = Get-FileHashValue -FilePath $SourcePath
            $hashDestino = Get-FileHashValue -FilePath $destinoPath

            if ($hashOrigem -eq $hashDestino) {
                $fileAge = (Get-Date) - (Get-Item $SourcePath).LastWriteTime
                if ($fileAge.Days -gt 7) {
                    Write-Log "Arquivo $relativoPath é mais antigo que 7 dias e está válido no destino. Removendo da origem."
                    if ($PSCmdlet.ShouldProcess($SourcePath, "Remover arquivo antigo $relativoPath")) {
                        Remove-Item -Path $SourcePath -Force -ErrorAction Stop
                        Write-Log "Arquivo removido da origem: $relativoPath"
                    }
                }
            }
        }
    }
    catch {
        Write-Log "Erro ao remover arquivo antigo $($DestinationPath): $_" -Level "ERROR"
        throw $_
    }
}

function Invoke-FileCopyProcess {
    try {
        Write-Log "Início da cópia de arquivos."

        $arquivosOrigem = Get-ChildItem -Path $Origem -Recurse -File -ErrorAction Stop
        foreach ($arquivo in $arquivosOrigem) {
            $destinoPath = Join-Path -Path $Destino -ChildPath (Get-RelativePath -BasePath $Origem -FullPath $arquivo.FullName)
            Copy-FileWithIntegrityCheck -SourcePath $arquivo.FullName -DestinationPath $destinoPath
        }

        Write-Log "Cópia concluída com sucesso."

        Write-Log "Iniciando remoção de arquivos antigos da origem."
        foreach ($arquivo in $arquivosOrigem) {
            Remove-OldFilesFromSource -SourcePath $arquivo.FullName -OrigemPath $Origem -DestinoPathBase $Destino
        }

        Write-Log "Remoção de arquivos antigos concluída."
    }
    catch {
        Write-Log "Erro durante o processo de cópia/remocão: $_" -Level "ERROR"
        throw $_
    }
}

try {
    if (-not (Test-Path -Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        Write-Log "Diretório de logs criado: $LogDir"
    }

    if (-not (Test-Path -Path $Origem)) {
        Write-Log "Diretório de origem não encontrado: $Origem" -Level "ERROR"
        throw "Diretório de origem não encontrado: $Origem"
    }

    if (-not (Test-Path -Path $Destino)) {
        Write-Log "Diretório de destino não encontrado: $Destino. Tentando criar."
        if ($PSCmdlet.ShouldProcess($Destino, "Criar diretório de destino")) {
            try {
                New-Item -ItemType Directory -Path $Destino -Force | Out-Null
                Write-Log "Diretório de destino criado: $Destino"
            }
            catch {
                Write-Log "Falha ao criar diretório de destino: $Destino. Erro: $_" -Level "ERROR"
                throw $_
            }
        }
    }

    Invoke-FileCopyProcess

    Write-Log "Processo finalizado com sucesso."
    exit 0
}
catch {
    Write-Log "Erro fatal durante a execução do script: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}