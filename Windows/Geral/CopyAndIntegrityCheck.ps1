<#
.SYNOPSIS
    Realiza a cópia de arquivos de um diretório de origem para um diretório de destino, 
    garantindo que apenas arquivos novos ou alterados sejam copiados e registrando o processo em um log.

.DESCRIPTION
    Este script PowerShell copia arquivos de um diretório de origem para um diretório de destino, 
    utilizando a verificação de hash para garantir a integridade dos arquivos copiados. 
    O processo é registrado em um arquivo de log para monitoramento e auditoria.

.PARAMETER Origem
    Caminho do diretório de origem onde os arquivos estão localizados.

.PARAMETER Destino
    Caminho do diretório de destino onde os arquivos serão copiados.

.PARAMETER LogDir
    Caminho do diretório onde os logs serão armazenados.

.EXAMPLE
    .\CopyAndIntegrityCheck.ps1

.NOTES
    Autor: Eduardo Augusto Gomes
    Data: 18/12/2024
    Versão: 1.0
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

Log "Início da cópia de arquivos."
try {
    $arquivosOrigem = Get-ChildItem -Path $Origem -Recurse -File
    foreach ($arquivo in $arquivosOrigem) {
        $relativoPath = $arquivo.FullName.Substring($Origem.Length)
        $destinoPath = Join-Path -Path $Destino -ChildPath $relativoPath

        $destinoDir = Split-Path -Path $destinoPath -Parent
        if (-not (Test-Path -Path $destinoDir)) {
            New-Item -ItemType Directory -Path $destinoDir | Out-Null
        }

        if (Test-Path -Path $destinoPath) {
            $hashOrigem = Get-FileHashValue -FilePath $arquivo.FullName
            $hashDestino = Get-FileHashValue -FilePath $destinoPath

            if ($hashOrigem -eq $hashDestino) {
                Log "Arquivo já existente e válido: $relativoPath. Nenhuma ação necessária."
            } else {
                Log "Hash divergente para $relativoPath. Substituindo arquivo."
                Copy-Item -Path $arquivo.FullName -Destination $destinoPath -Force -ErrorAction Stop
            }
        } else {
            Log "Arquivo não encontrado no destino: $relativoPath. Realizando cópia."
            Copy-Item -Path $arquivo.FullName -Destination $destinoPath -Force -ErrorAction Stop
        }
    }

    Log "Cópia concluída com sucesso."
} catch {
    Log "Erro durante o processo: $_" -Level "ERROR"
    exit 1
}

Log "Processo finalizado com sucesso."
exit 0