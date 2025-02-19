# Define o caminho do executável e os parâmetros
$exePath = "\\ad01\util$\softwares\teamsbootstrapper.exe"
$params = "-p -o '\\ad01\util$\softwares\MSTeams-x64.msix'"

# Define o caminho do arquivo de log
$logPath = "C:\path\to\error.log"

# Função para garantir que o diretório do log exista
function Ensure-LogDirectoryExists {
    param (
        [string]$logPath
    )
    $logDirectory = [System.IO.Path]::GetDirectoryName($logPath)
    if (-not (Test-Path -Path $logDirectory)) {
        New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
    }
}

# Função para registrar o erro em um log
function Log-Error {
    param (
        [string]$message
    )
    Ensure-LogDirectoryExists -logPath $logPath
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Add-Content -Path $logPath -Value $logMessage
}

# Função para traduzir códigos HRESULT para mensagens de erro
function Get-HResultMessage {
    param (
        [int]$hresult
    )
    switch ($hresult) {
        0x00000000 { return "Operation successful (S_OK)" }
        0x80004001 { return "Not implemented (E_NOTIMPL)" }
        0x80004002 { return "No such interface supported (E_NOINTERFACE)" }
        0x80004003 { return "Pointer that is not valid (E_POINTER)" }
        0x80004004 { return "Operation aborted (E_ABORT)" }
        0x80004005 { return "Unspecified failure (E_FAIL)" }
        0x8000FFFF { return "Unexpected failure (E_UNEXPECTED)" }
        0x80070005 { return "General access denied error (E_ACCESSDENIED)" }
        0x80070006 { return "Handle that is not valid (E_HANDLE)" }
        0x8007000E { return "Failed to allocate necessary memory (E_OUTOFMEMORY)" }
        0x80070057 { return "One or more arguments are not valid (E_INVALIDARG)" }
        default { return "Unknown error (HRESULT: 0x{0:X})" -f $hresult }
    }
}

try {
    # Executa o comando e captura a saída
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $exePath
    $processInfo.Arguments = $params
    $processInfo.RedirectStandardError = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($processInfo)

    # Aguarda a conclusão do processo
    $process.WaitForExit()

    # Verifica o código de saída do processo
    $exitCode = $process.ExitCode
    if ($exitCode -eq 0) {
        Write-Output "O comando foi executado com sucesso."
    } else {
        $errorMessage = "Erro ao executar o comando. Código de erro: $($exitCode)"
        $standardError = $process.StandardError.ReadToEnd()
        if ($standardError) {
            $errorMessage += ", Saída de erro: $standardError"
        }
        Log-Error -message $errorMessage
        Write-Error $errorMessage
    }

} catch {
    # Captura o código HRESULT do erro
    $hresult = [System.Runtime.InteropServices.Marshal]::GetHRForException($_.Exception)
    $errorMessage = Get-HResultMessage -hresult $hresult
    Log-Error -message "Erro ao executar o comando: $errorMessage"
    Log-Error -message "Detalhes do erro: $_"
    Write-Error "Ocorreu um erro ao executar o comando. Verifique o log para mais detalhes. Erro: $errorMessage"
}
