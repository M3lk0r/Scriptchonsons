<#
.SYNOPSIS
    Realiza a cópia de arquivos de um diretório de origem para um diretório de destino 
    utilizando o comando Robocopy e valida a integridade dos arquivos copiados.

.DESCRIPTION
    Este script PowerShell utiliza o Robocopy para copiar arquivos de um diretório de origem para um 
    diretório de destino, garantindo que os arquivos sejam idênticos aos da origem através da verificação de hash. 
    O processo é registrado em um arquivo de Write-Log para monitoramento e auditoria.

.PARAMETER Origem
    Caminho do diretório de origem onde os arquivos estão localizados.

.PARAMETER Destino
    Caminho do diretório de destino onde os arquivos serão copiados.

.PARAMETER logDir
    Caminho do diretório onde os Write-Logs serão armazenados.

.EXAMPLE
    .\CopyWithTrafficLimitAndIntegrityCheck.ps1

.NOTES
    Autor: Eduardo Augusto Gomes
    Data: 28/02/2025
    Versão: 1.2
        Melhoria nos logs.

.LINK
    https://github.com/M3lk0r/Powershellson
#>

$origem = "C:\\Origem"
$destino = "C:\\Destino"
$logDir = "C:\\logs"

if (-not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$DataHora = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = Join-Path -Path $logDir -ChildPath "Copia_Arquivos_$DataHora.Write-Log"

function Get-FileHashValue {
    param (
        [string]$FilePath
    )
    return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
}

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

Write-Log "Início da cópia de arquivos com Robocopy e limitação de tráfego."
try {
    $cmd = "Robocopy `"$Origem`" `"$Destino`" /E /R:3 /W:5 /Write-Log+:`"$Write-LogFile`" /IPG:2"
    Write-Log "Executando comando: $cmd"
    Invoke-Expression -Command $cmd
    Write-Log "Cópia inicial concluída com sucesso usando Robocopy."
} catch {
    Write-Log "Erro durante o processo de cópia com Robocopy: $_" -Level "ERROR"
    exit 1
}

Write-Log "Iniciando validação de integridade."

try {
    $arquivosOrigem = Get-ChildItem -Path $Origem -Recurse -File
    foreach ($arquivo in $arquivosOrigem) {
        $relativoPath = $arquivo.FullName.Substring($Origem.Length).TrimStart('\')
        $destinoPath = Join-Path -Path $Destino -ChildPath $relativoPath

        $destinoDir = Split-Path -Path $destinoPath -Parent
        if (-not (Test-Path -Path $destinoDir)) {
            New-Item -ItemType Directory -Path $destinoDir | Out-Null
        }

        if (Test-Path -Path $destinoPath) {
            $hashOrigem = Get-FileHashValue -FilePath $arquivo.FullName
            $hashDestino = Get-FileHashValue -FilePath $destinoPath

            if ($hashOrigem -eq $hashDestino) {
                Write-Log "Arquivo válido no destino: $relativoPath. Nenhuma ação necessária."
            } else {
                Write-Log "Hash divergente para $relativoPath. Substituindo arquivo."
                Copy-FileWithRetry -SourcePath $arquivo.FullName -DestinationPath $destinoPath
            }
        } else {
            Write-Log "Arquivo não encontrado no destino: $relativoPath. Realizando cópia."
            Copy-FileWithRetry -SourcePath $arquivo.FullName -DestinationPath $destinoPath
        }
    }
    Write-Log "Validação de integridade concluída com sucesso."
} catch {
    Write-Log "Erro durante a validação de integridade: $_" -Level "ERROR"
    exit 1
}

Write-Log "Processo finalizado com sucesso."
exit 0