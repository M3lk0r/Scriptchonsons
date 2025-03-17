<#
.SYNOPSIS
    Realiza a cópia de arquivos de um diretório de origem autenticado para um diretório de destino, verificando a integridade dos arquivos e removendo arquivos antigos da origem.

.DESCRIPTION
    Este script copia arquivos de um diretório de origem que requer autenticação para um diretório de destino, verificando a integridade dos arquivos através de hash SHA256.
    Após a cópia, arquivos na origem que são mais antigos que 7 dias e já estão validados no destino são removidos.

.PARAMETER Origem
    Caminho do diretório de origem.

.PARAMETER Destino
    Caminho do diretório de destino.

.PARAMETER LogDir
    Caminho do diretório de logs. Padrão C:\Logs.

.PARAMETER CredencialOrigem
    Credencial de autenticação para o diretório de origem (PSCredential).

.EXAMPLE
    ex 1:
    $usuario = "DOMINIO\usuario"
    $senha = ConvertTo-SecureString "senha" -AsPlainText -Force
    $credencial = New-Object System.Management.Automation.PSCredential ($usuario, $senha)
    .\CopyFilesWithAuth.ps1 -Origem "\\servidor\compartilhamento" -Destino "C:\Destino" -CredencialOrigem $credencial

    ex 2:
    $credencial = Get-Credential
    .\CopyFilesWithAuth.ps1 -Origem "\\servidor\compartilhamento" -Destino "C:\Destino" -CredencialOrigem $credencial

.NOTES
    Autor: Eduardo Augusto Gomes (eduardo.agms@outlook.com.br)
    Data: 28/02/2025
    Versão: 1.0

.LINK
    https://github.com/M3lk0r/Scriptchonsons
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter(Mandatory = $true)]
    [string]$Origem,

    [Parameter(Mandatory = $true)]
    [string]$Destino,

    [Parameter(Mandatory = $false)]
    [string]$LogDir = "C:\Logs",

    [Parameter(Mandatory = $true)]
    [System.Management.Automation.PSCredential]$CredencialOrigem
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

function Add-NetworkDrive {
    param (
        [string]$Path,
        [System.Management.Automation.PSCredential]$Credential
    )
    New-PSDrive -Name "OrigemDrive" -PSProvider FileSystem -Root $Path -Credential $Credential -Persist -ErrorAction Stop | Out-Null
    return "OrigemDrive:\"
}

try {
    if (-not (Test-Path -Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

    Write-Log "Autenticando no diretório de origem..."
    $MappedOrigem = Add-NetworkDrive -Path $Origem -Credential $CredencialOrigem
    
    if (-not (Test-Path -Path $MappedOrigem)) {
        Write-Log "Falha ao acessar o diretório de origem." -Level "ERROR"
        exit 1
    }
    
    Write-Log "Início da cópia de arquivos."
    Get-ChildItem -Path $MappedOrigem -Recurse -File | ForEach-Object {
        $relPath = $_.FullName.Substring($MappedOrigem.Length).TrimStart('\')
        $destPath = Join-Path -Path $Destino -ChildPath $relPath
        
        if (-not (Test-Path -Path (Split-Path -Path $destPath -Parent))) {
            New-Item -ItemType Directory -Path (Split-Path -Path $destPath -Parent) -Force | Out-Null
        }

        if (Test-Path -Path $destPath) {
            $hashOrigem = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
            $hashDestino = (Get-FileHash -Path $destPath -Algorithm SHA256).Hash
            if ($hashOrigem -ne $hashDestino) {
                Copy-Item -Path $_.FullName -Destination $destPath -Force
                Write-Log "Arquivo atualizado: $relPath"
            }
            else {
                Write-Log "Arquivo já está atualizado: $relPath"
            }
        }
        else {
            Copy-Item -Path $_.FullName -Destination $destPath -Force
            Write-Log "Arquivo copiado: $relPath"
        }
    }
    
    Write-Log "Cópia concluída. Iniciando remoção de arquivos antigos."
    Get-ChildItem -Path $MappedOrigem -Recurse -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | ForEach-Object {
        $relPath = $_.FullName.Substring($MappedOrigem.Length).TrimStart('\')
        $destPath = Join-Path -Path $Destino -ChildPath $relPath
        if (Test-Path -Path $destPath) {
            Remove-Item -Path $_.FullName -Force
            Write-Log "Arquivo removido: $relPath"
        }
    }

    Write-Log "Processo finalizado com sucesso."
    exit 0
}
catch {
    Write-Log "Erro fatal: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}