<#
.SYNOPSIS
    Instala certificados .p12 para usuarios de um grupo do Active Directory.

.DESCRIPTION
    Este script instala certificados .p12 para usuarios que pertencem a um grupo específico do Active Directory.
    Os certificados e senhas são lidos de um arquivo JSON, e o script inclui logging avançado, feedback visual e tratamento de erros.

.PARAMETER GrupoCertificados
    O nome do grupo do Active Directory cujos usuarios receberão os certificados.
    Exemplo: "Certificado_Usuarios"

.PARAMETER CaminhoJson
    O caminho completo para o arquivo JSON que contém a lista de certificados e senhas.
    Exemplo: "\\caminho\para\certificados.json"

.EXAMPLE
    .\InstalarCertificados.ps1 -GrupoCertificados "Certificado_Usuarios" -CaminhoJson "\\caminho\para\certificados.json"

.NOTES
    Autor: Eduardo Augusto Gomes (eduardo.agms@outlook.com.br)
    Data: 04/02/2025
    Versão: 1.2
        - Melhoria no log

.LINK
    Repositório: https://github.com/M3lk0r/Powershellson
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$GrupoCertificados,

    [Parameter(Mandatory = $true)]
    [string]$CaminhoJson
)

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Log "Este script requer PowerShell 5 ou superior." -tipo "ERRO"
    exit
}

$caminhoLogs = "C:\logs\"

function Write-Log {
    param (
        [string]$mensagem,
        [string]$tipo = "INFO"
    )

    $dataHora = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$dataHora] [$tipo] $mensagem"
    $logPath = "$caminhoLogs\certificados.log"

    if (-not (Test-Path $logPath)) {
        [System.IO.File]::WriteAllText($logPath, "`uFEFF", [System.Text.Encoding]::UTF8)
    }

    $logEntry | Out-File -FilePath $logPath -Encoding UTF8 -Append

    switch ($tipo) {
        "INFO" { Write-Host $logEntry -ForegroundColor Green }
        "ERRO" { Write-Host $logEntry -ForegroundColor Red }
        "AVISO" { Write-Host $logEntry -ForegroundColor Yellow }
        default { Write-Host $logEntry }
    }
}

function Import-Certificados {
    param (
        [string]$usuario,
        [string]$caminhoPadraoCertificados,
        [array]$certificados
    )

    Write-Progress -Activity "Instalando Certificados" -Status "Iniciando processo para $usuario" -PercentComplete 0
    $totalCertificados = $certificados.Count
    $contador = 0

    foreach ($certificado in $certificados) {
        $contador++
        $percentual = [math]::Round(($contador / $totalCertificados) * 100, 2)

        if ($contador % 5 -eq 0 -or $contador -eq $totalCertificados) {
            Write-Progress -Activity "Instalando Certificados" -Status "Processando $($certificado.Nome)" -PercentComplete $percentual
        }

        $caminhoCertificado = "$caminhoPadraoCertificados\$($certificado.Nome)"
        
        if (-not (Test-Path -Path $caminhoCertificado)) {
            Write-Log "Certificado $($certificado.Nome) não encontrado no caminho: $caminhoCertificado." -tipo "AVISO"
            continue
        }

        try {
            $securePassword = ConvertTo-SecureString -String $certificado.Senha -AsPlainText -Force
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
                $caminhoCertificado, 
                $securePassword, 
                [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet
            )

            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", "CurrentUser")
            $store.Open("ReadWrite")
            $store.Add($cert)
            $store.Close()

            Write-Log "Certificado $($certificado.Nome) instalado com sucesso para o usuário $usuario."
        }
        catch {
            Write-Log "Erro ao instalar o certificado $($certificado.Nome): $($_.Exception.Message)" -tipo "ERRO"
        }
    }
    
    Write-Progress -Activity "Instalando Certificados" -Completed
}

function Clear-CertificadosExpirados {
    param (
        [string]$usuario
    )

    try {
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", "CurrentUser")
        $store.Open("ReadWrite")
        $certsToRemove = $store.Certificates | Where-Object { $_.NotAfter -lt (Get-Date) }
        foreach ($expiredCert in $certsToRemove) {
            $store.Remove($expiredCert)
            Write-Log "Certificado expirado $($expiredCert.Thumbprint) removido do repositório do usuario $usuario."
        }
        $store.Close()
    }
    catch {
        Write-Log "Erro ao remover certificados expirados: $($_.Exception.Message)" -tipo "ERRO"
    }
}

if (-not (Test-Path -Path $caminhoLogs)) {
    New-Item -ItemType Directory -Path $caminhoLogs | Out-Null
    Write-Log "Diretório de logs criado: $caminhoLogs."
}

$user = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$usuarioSam = $user.Name.Split("\")[-1]

$groupObj = [ADSI]"WinNT://$env:USERDOMAIN/$GrupoCertificados,group"
$members = @($groupObj.Invoke("Members")) | ForEach-Object { $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null) }

$isMember = $members -contains $usuarioSam


if ($isMember) {
    Write-Log "usuario $($user.Name) pertence ao grupo $GrupoCertificados. Iniciando instalação de certificados."

    try {
        $jsonContent = Get-Content -Path $CaminhoJson -Raw | ConvertFrom-Json
        $caminhoPadraoCertificados = $jsonContent.CaminhoPadraoCertificados
        $certificados = $jsonContent.Certificados
        Write-Log "Arquivo JSON carregado com sucesso. Caminho padrão: $caminhoPadraoCertificados."
    }
    catch {
        Write-Log "Erro ao carregar o arquivo JSON: $($_.Exception.Message)" -tipo "ERRO"
        exit
    }

    Import-Certificados -usuario $user.Name -caminhoPadraoCertificados $caminhoPadraoCertificados -certificados $certificados

    Clear-CertificadosExpirados -usuario $user.Name
}
else {
    Write-Log "usuario $($user.Name) não pertence ao grupo $GrupoCertificados. Nenhum certificado será instalado." -tipo "AVISO"
}