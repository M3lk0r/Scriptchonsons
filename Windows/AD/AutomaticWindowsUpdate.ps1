<#
.SYNOPSIS
    Executa a atualização automática do Windows, verificando e instalando patches disponíveis.

.DESCRIPTION
    O script verifica a origem das atualizações (Microsoft Update ou WSUS), faz o download e instala as atualizações disponíveis.
    Ele também registra logs das operações realizadas.

.EXAMPLE
    .\AutomaticWindowsUpdate.ps1

.NOTES
    Autor: Eduardo Augusto Gomes (eduardo.agms@outlook.com.br)
    Data: 04/02/2025
    Versão: 2.1
        - Adicionado log da origem das atualizações (WSUS ou Microsoft Update)
        - Melhorias na exibição e organização do código

.LINK
    https://github.com/M3lk0r/Powershellson
#>

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires administrative privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

$logFile = "$env:TEMP\WindowsUpdate.log"

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

function Install-BurntToast {
    if (-not (Get-Module -ListAvailable -Name BurntToast)) {
        Write-Log "Installing BurntToast module..." -Level "INFO"
        Install-Module -Name BurntToast -Force -Scope CurrentUser
    }
    Import-Module -Name BurntToast
}

function Send-Notification {
    param (
        [string]$Message
    )
    try {
        New-BurntToastNotification -Text "Windows Update", $Message -AppLogo "$env:SystemRoot\System32\SHELL32.dll" -Silent
        Write-Log "Notification sent: $Message" -Level "INFO"
    }
    catch {
        Write-Log "Failed to send notification: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Get-UpdateSource {
    $wuRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    $wuAUServer = "$wuRegistryPath\AU"

    if (Test-Path $wuRegistryPath) {
        $useWUServer = Get-ItemProperty -Path $wuAUServer -Name "UseWUServer" -ErrorAction SilentlyContinue
        if ($useWUServer -and $useWUServer.UseWUServer -eq 1) {
            $wuServer = Get-ItemProperty -Path $wuRegistryPath -Name "WUServer" -ErrorAction SilentlyContinue
            if ($wuServer) {
                Write-Log "Updates are being sourced from WSUS server: $($wuServer.WUServer)" -Level "INFO"
                return "WSUS", $wuServer.WUServer
            }
        }
    }

    Write-Log "Updates are being sourced directly from Microsoft." -Level "INFO"
    return "Microsoft", $null
}

function Get-WindowsUpdates {
    try {
        Write-Log "Checking for available updates... Please wait!" -Level "INFO"
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        $SearchResult = $UpdateSearcher.Search("IsInstalled=0").Updates
        return $SearchResult
    }
    catch {
        Write-Log "Failed to check for updates: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

function Download-Updates {
    param (
        [array]$Updates
    )
    try {
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdatesDownloader = $UpdateSession.CreateUpdateDownloader()
        $UpdatesDownloader.Updates = $Updates
        $UpdatesDownloader.Priority = 3

        Write-Log "Downloading updates..." -Level "INFO"
        $DownloadResult = $UpdatesDownloader.Download()

        switch ($DownloadResult.ResultCode) {
            0 { Write-Log "Download not started." -Level "WARNING" }
            1 { Write-Log "Download in progress." -Level "INFO" }
            2 { Write-Log "Download succeeded." -Level "INFO" }
            3 { Write-Log "Download succeeded with errors." -Level "WARNING" }
            4 { Write-Log "Download failed." -Level "ERROR" }
            5 { Write-Log "Download aborted." -Level "ERROR" }
        }
    }
    catch {
        Write-Log "Failed to download updates: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

function Install-Updates {
    param (
        [array]$Updates
    )
    try {
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdatesInstaller = $UpdateSession.CreateUpdateInstaller()
        $UpdatesInstaller.Updates = $Updates

        Write-Log "Installing updates..." -Level "INFO"
        $InstallResult = $UpdatesInstaller.Install()

        switch ($InstallResult.ResultCode) {
            0 { Write-Log "Installation not started." -Level "WARNING" }
            1 { Write-Log "Installation in progress." -Level "INFO" }
            2 { Write-Log "Installation succeeded." -Level "INFO" }
            3 { Write-Log "Installation succeeded with errors." -Level "WARNING" }
            4 { Write-Log "Installation failed." -Level "ERROR" }
            5 { Write-Log "Installation aborted." -Level "ERROR" }
        }

        return $InstallResult.RebootRequired
    }
    catch {
        Write-Log "Failed to install updates: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

try {
    Install-BurntToast

    $updateSource, $wsusServer = Get-UpdateSource
    if ($updateSource -eq "WSUS") {
        Write-Log "WSUS Server URL: $wsusServer" -Level "INFO"
    }

    $updates = Get-WindowsUpdates
    if ($updates.Count -eq 0) {
        Write-Log "No updates available." -Level "INFO"
        exit 0
    }

    Write-Log "Found $($updates.Count) updates:" -Level "INFO"
    $updates | ForEach-Object { Write-Log "- $($_.Title)" -Level "INFO" }

    Download-Updates -Updates $updates

    $needsReboot = Install-Updates -Updates $updates

    if ($needsReboot) {
        Write-Log "A reboot is required to complete the installation." -Level "INFO"
        Send-Notification -Message "The system will reboot in 5 minutes to complete updates. Save your work!"
        Start-Sleep -Seconds 300
        Write-Log "Rebooting the system..." -Level "INFO"
        Restart-Computer -Force
    }
    else {
        Write-Log "No reboot required. All updates installed successfully." -Level "INFO"
    }
}
catch {
    Write-Log "An unexpected error occurred: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}