<#
.SYNOPSIS
    Baixa um vídeo do YouTube para a pasta Downloads do usuário atual.

.DESCRIPTION
    Este script recebe uma URL de um vídeo do YouTube e baixa o arquivo de vídeo utilizando o yt-dlp.
    Caso o yt-dlp não esteja instalado, o script faz o download automaticamente.
    O script também verifica a presença do ffmpeg e o instala automaticamente se não estiver disponível.
    O usuário pode definir o formato do arquivo e a qualidade do vídeo.

.PARAMETER VideoURL
    A URL do vídeo do YouTube a ser baixado.

.PARAMETER Format
    O formato do arquivo a ser baixado (ex: mp4, mkv, webm, mp3). Padrão: mkv.

.PARAMETER Quality
    A qualidade do vídeo a ser baixado. Padrão: melhor qualidade disponível.

.PARAMETER Overwrite
    Se definido, sobrescreve arquivos existentes. Padrão: False.

.EXAMPLE
    .\Download-YouTube.ps1 -VideoURL "https://www.youtube.com/watch?v=dQw4w9WgXcQ" -Format "mp3"

.NOTES
    Autor: Eduardo Augusto Gomes (eduardo.agms@outlook.com.br)
    Data: 04/02/2025
    Versão: 1.5
        - Ajustada instalação do ffmpeg para baixar binários pré-compilados diretamente.
        - Melhorias na robustez do script.
        - Atualizações nos argumentos do yt-dlp.
        - Ainda não funciona tudo nesse lixo

.LINK
    Repositório: https://github.com/M3lk0r/Powershellson
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Informe a URL do vídeo do YouTube.")]
    [string]$VideoURL,

    [Parameter(Mandatory = $false, HelpMessage = "Formato do arquivo (ex: mp4, mkv, webm, mp3). Padrão: mkv.")]
    [string]$Format = "mkv",

    [Parameter(Mandatory = $false, HelpMessage = "Qualidade do vídeo (ex: best, worst, 720p, 1080p). Padrão: melhor qualidade disponível.")]
    [string]$Quality = "best",

    [Parameter(Mandatory = $false, HelpMessage = "Sobrescrever arquivos existentes.")]
    [switch]$Overwrite
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$DownloadFolder = [System.IO.Path]::Combine($env:USERPROFILE, "Downloads")
$ytDlpPath = [System.IO.Path]::Combine($env:APPDATA, "yt-dlp", "yt-dlp.exe")
$logFile = [System.IO.Path]::Combine($env:APPDATA, "Download-YouTube.log")
$ffmpegFolder = [System.IO.Path]::Combine($env:APPDATA, "ffmpeg")
$ffmpegPath = [System.IO.Path]::Combine($ffmpegFolder, "ffmpeg.exe")

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    try {
        $dataHora = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$dataHora] [$Level] $Message"

        $logDir = [System.IO.Path]::GetDirectoryName($logFile)
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        $logEntry | Out-File -FilePath $logFile -Encoding UTF8 -Append

        $color = @{ "INFO" = "Green"; "ERROR" = "Red"; "WARNING" = "Yellow" }
        Write-Host $logEntry -ForegroundColor $color[$Level]
    }
    catch {
        Write-Host "Erro ao escrever no log: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Install-YtDlp {
    try {
        Write-Log "Baixando yt-dlp..."
        $ytDlpDir = [System.IO.Path]::GetDirectoryName($ytDlpPath)
        if (-not (Test-Path $ytDlpDir)) {
            New-Item -ItemType Directory -Path $ytDlpDir -Force | Out-Null
        }
        Invoke-WebRequest -Uri "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" -OutFile $ytDlpPath
        Write-Log "yt-dlp baixado com sucesso para $ytDlpPath."
    }
    catch {
        Write-Log "Erro ao baixar yt-dlp: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

function Install-Ffmpeg {
    try {
        Write-Log "ffmpeg não encontrado. Iniciando instalação automática..."

        $ffmpegDownloadUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-essentials.7z"
        Write-Log "Baixando ffmpeg de $ffmpegDownloadUrl..."

        $tempArchive = [System.IO.Path]::Combine($env:TEMP, "ffmpeg.7z")

        Invoke-WebRequest -Uri $ffmpegDownloadUrl -OutFile $tempArchive

        Write-Log "Extraindo ffmpeg para $ffmpegFolder..."

        if (-not (Test-Path $ffmpegFolder)) {
            New-Item -ItemType Directory -Path $ffmpegFolder -Force | Out-Null
        }

        $sevenZipPath = "C:\Program Files\7-Zip\7z.exe"
        if (-not (Test-Path $sevenZipPath)) {
            Write-Log "7-Zip não encontrado. Instale o 7-Zip para continuar." -Level "ERROR"
            exit 1
        }

        Start-Process -FilePath $sevenZipPath -ArgumentList "x `"$tempArchive`" -o`"$ffmpegFolder`" -aoa" -NoNewWindow -Wait

        $ffmpegExe = Get-ChildItem -Path $ffmpegFolder -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1

        if (-not $ffmpegExe) {
            Write-Log "Não foi possível encontrar o ffmpeg.exe após a extração." -Level "ERROR"
            exit 1
        }

        Move-Item -Path $ffmpegExe.FullName -Destination $ffmpegFolder -Force

        Get-ChildItem -Path $ffmpegFolder | Where-Object { $_.Name -ne "ffmpeg.exe" } | Remove-Item -Recurse -Force

        Remove-Item -Path $tempArchive -Force

        Write-Log "ffmpeg instalado com sucesso em $ffmpegPath."
    }
    catch {
        Write-Log "Erro ao instalar ffmpeg: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

function Get-YouTubeVideo {
    param (
        [string]$VideoURL,
        [string]$Format = "mkv",
        [string]$Quality = "best",
        [string]$DownloadFolder = "$env:USERPROFILE\Downloads",
        [switch]$Overwrite
    )

    if (-not (Test-Path $ytDlpPath)) {
        Write-Log "yt-dlp não encontrado. Iniciando instalação."
        Install-YtDlp
    }

    if (-not (Test-Path $ffmpegPath)) {
        Install-Ffmpeg
    }

    try {
        Write-Log "Atualizando yt-dlp para a última versão..."
        Start-Process -FilePath $ytDlpPath -ArgumentList "-U" -NoNewWindow -Wait
        Write-Log "yt-dlp atualizado com sucesso."
    }
    catch {
        Write-Log "Erro ao atualizar yt-dlp: $($_.Exception.Message)" -Level "WARNING"
    }

    $outputTemplate = "$DownloadFolder\%(title)s.%(ext)s"

    $Arguments = @(
        $VideoURL,
        "-o", $outputTemplate,
        "--no-warnings",
        "--progress",
        "--embed-metadata",
        "--embed-thumbnail",
        "--add-metadata",
        "--restrict-filenames",
        "--ffmpeg-location", $ffmpegFolder,
        "--no-continue",
        "--rm-cache-dir"
    )

    if ($Format -eq "mp3") {
        $Arguments += "--extract-audio"
        $Arguments += "--audio-format", "mp3"
    } else {
        # Força o uso do formato especificado
        $Arguments += "-f", "bestvideo[ext=$Format]+bestaudio[ext=m4a]/best[ext=$Format]/best"
        $Arguments += "--remux-video", $Format
    }

    if ($Overwrite) {
        $Arguments += "--force-overwrites"
    } else {
        $Arguments += "--no-overwrites"
    }

    try {
        Write-Log "Baixando vídeo de $VideoURL com formato $Format e qualidade $Quality para $DownloadFolder..."
        Start-Process -FilePath $ytDlpPath -ArgumentList $Arguments -NoNewWindow -Wait
        Write-Log "Download concluído com sucesso."
    }
    catch {
        Write-Log "Erro ao baixar vídeo: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

Get-YouTubeVideo -VideoURL $VideoURL -Format $Format -Quality $Quality -DownloadFolder $DownloadFolder -Overwrite:$Overwrite