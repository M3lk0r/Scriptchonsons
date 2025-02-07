<#
.SYNOPSIS
    Realiza a cópia de arquivos de um diretório de origem para um diretório de destino 
    utilizando o comando Robocopy e valida a integridade dos arquivos copiados.

.DESCRIPTION
    Este script PowerShell utiliza o Robocopy para copiar arquivos de um diretório de origem para um 
    diretório de destino, garantindo que os arquivos sejam idênticos aos da origem através da verificação de hash. 
    O processo é registrado em um arquivo de log para monitoramento e auditoria.

.PARAMETER Origem
    Caminho do diretório de origem onde os arquivos estão localizados.

.PARAMETER Destino
    Caminho do diretório de destino onde os arquivos serão copiados.

.PARAMETER LogDir
    Caminho do diretório onde os logs serão armazenados.

.EXAMPLE
    .\CopyWithTrafficLimitAndIntegrityCheck.ps1

.NOTES
    Autor: Eduardo Augusto Gomes
    Data: 18/12/2024
    Versão: 1.1
        Versão inicial do script.

.LINK
    https://github.com/M3lk0r/Powershellson
#>

$origem = "C:\\Origem"
$destino = "C:\\Destino"
$logDir = "C:\\Logs"

if (-not (Test-Path -Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

$DataHora = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFile = Join-Path -Path $LogDir -ChildPath "Copia_Arquivos_$DataHora.log"

function Get-FileHashValue {
    param (
        [string]$FilePath
    )
    return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash
}

function Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    Add-Content -Path $LogFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
}

Log "Início da cópia de arquivos com Robocopy e limitação de tráfego."
try {
    $cmd = "Robocopy `"$Origem`" `"$Destino`" /E /R:3 /W:5 /LOG+:`"$LogFile`" /IPG:2"
    Log "Executando comando: $cmd"
    Invoke-Expression -Command $cmd
    Log "Cópia inicial concluída com sucesso usando Robocopy."
} catch {
    Log "Erro durante o processo de cópia com Robocopy: $_" -Level "ERROR"
    exit 1
}

Log "Iniciando validação de integridade."

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
                Log "Arquivo válido no destino: $relativoPath. Nenhuma ação necessária."
            } else {
                Log "Hash divergente para $relativoPath. Substituindo arquivo."
                Copy-FileWithRetry -SourcePath $arquivo.FullName -DestinationPath $destinoPath
            }
        } else {
            Log "Arquivo não encontrado no destino: $relativoPath. Realizando cópia."
            Copy-FileWithRetry -SourcePath $arquivo.FullName -DestinationPath $destinoPath
        }
    }
    Log "Validação de integridade concluída com sucesso."
} catch {
    Log "Erro durante a validação de integridade: $_" -Level "ERROR"
    exit 1
}

Log "Processo finalizado com sucesso."
exit 0