# Script para instalar Spotify automaticamente e criar atalho na área de trabalho pública

# URL do instalador offline do Spotify
$spotifyInstallerUrl = "https://download.scdn.co/SpotifySetup.exe"
$installerPath = "$env:TEMP\SpotifySetup.exe"

# Baixar o instalador do Spotify
try {
    Invoke-WebRequest -Uri $spotifyInstallerUrl -OutFile $installerPath
    Write-Output "Instalador do Spotify baixado com sucesso."
} catch {
    Write-Error "Falha ao baixar o instalador do Spotify: $_"
    exit 1
}

# Executar o instalador do Spotify silenciosamente
try {
    Start-Process -FilePath $installerPath -ArgumentList "/silent" -NoNewWindow -Wait
    Write-Output "Spotify instalado com sucesso."
} catch {
    Write-Error "Falha ao instalar o Spotify: $_"
    exit 1
}

# Verificar se o Spotify foi instalado
$spotifyApp = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "Spotify" }
if ($spotifyApp -eq $null) {
    Write-Error "A instalação do Spotify falhou ou o aplicativo não foi encontrado."
    exit 1
}

# Criar um atalho para o Spotify na área de trabalho pública
$PublicDesktop = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Public"), "Desktop")
$shortcutPath = [System.IO.Path]::Combine($PublicDesktop, "Spotify.lnk")

# Caminho de destino do atalho
$TargetPath = "C:\Users\$env:USERNAME\AppData\Roaming\Spotify\Spotify.exe"

# Criação do atalho
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = $TargetPath
$Shortcut.WorkingDirectory = "C:\Users\$env:USERNAME\AppData\Roaming\Spotify"
$Shortcut.Save()

Write-Output "Spotify foi instalado e o atalho foi criado com sucesso."
