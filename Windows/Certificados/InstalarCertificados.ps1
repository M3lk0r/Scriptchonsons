<#
.SYNOPSIS
    Instala certificados .p12 para usuários de um grupo do Active Directory.

.DESCRIPTION
    Este script instala certificados .p12 para usuários que pertencem a um grupo específico do Active Directory.
    Os certificados e senhas são lidos de um arquivo JSON, e o script inclui logging avançado, feedback visual e tratamento de erros.

.PARAMETER GrupoCertificados
    O nome do grupo do Active Directory cujos usuários receberão os certificados.
    Exemplo: "Certificado_Usuarios"

.PARAMETER CaminhoJson
    O caminho completo para o arquivo JSON que contém a lista de certificados e senhas.
    Exemplo: "\\caminho\para\certificados.json"

.EXAMPLE
    .\InstalarCertificados.ps1 -GrupoCertificados "Certificado_Usuarios" -CaminhoJson "\\caminho\para\certificados.json"

.NOTES
    Autor: Eduardo Augusto Gomes (eduardo.agms@outlook.com.br)
    Data: 03/02/2025
    Versão: 1.0
        - Baseado no script original de instalação de certificados.
        - Adicionada modularização, logging avançado e feedback visual.
        - Verificação da versão do PowerShell.
        - Otimização no uso de Write-Progress.

.LINK
    Repositório: https://github.com/M3lk0r/Powershellson
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$GrupoCertificados,

    [Parameter(Mandatory = $true)]
    [string]$CaminhoJson
)

# Verifica a versão do PowerShell
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "Este script requer PowerShell 5 ou superior." -ForegroundColor Red
    exit
}

# Configurações
$caminhoLogs = "C:\logs\" # Caminho para salvar os logs

# Função para registrar logs
function Write-Log {
    param (
        [string]$mensagem,
        [string]$tipo = "INFO"
    )
    $dataHora = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$dataHora] [$tipo] $mensagem"
    Add-Content -Path "$caminhoLogs\certificados.log" -Value $logEntry

    # Feedback visual
    switch ($tipo) {
        "INFO" { Write-Host $logEntry -ForegroundColor Green }
        "ERRO" { Write-Host $logEntry -ForegroundColor Red }
        "AVISO" { Write-Host $logEntry -ForegroundColor Yellow }
        default { Write-Host $logEntry }
    }
}

# Função para instalar certificados
function Import-Certificados {
    param (
        [string]$usuario,
        [string]$caminhoPadraoCertificados,
        [array]$certificados
    )

    Write-Progress -Activity "Instalando Certificados" -Status "Processando $usuario" -PercentComplete 0
    $totalCertificados = $certificados.Count
    $contador = 0

    foreach ($certificado in $certificados) {
        $contador++
        $percentual = ($contador / $totalCertificados) * 100
        Write-Progress -Activity "Instalando Certificados" -Status "Processando $($certificado.Nome)" -PercentComplete $percentual

        $certPath = "$caminhoPadraoCertificados\$($certificado.Nome)"
        $certPassword = $certificado.Senha

        if (Test-Path -Path $certPath) {
            try {
                # Importa o certificado para o repositório pessoal do usuário
                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
                $cert.Import($certPath, $certPassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::UserKeySet)
                Write-Log "Certificado $($certificado.Nome) instalado com sucesso para o usuário $usuario."
            } catch {
                Write-Log "Erro ao instalar o certificado $($certificado.Nome): $_" -tipo "ERRO"
            }
        } else {
            Write-Log "Certificado $($certificado.Nome) não encontrado no caminho $certPath." -tipo "AVISO"
        }
    }
}

# Função para remover certificados expirados
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
            Write-Log "Certificado expirado $($expiredCert.Thumbprint) removido do repositório do usuário $usuario."
        }
        $store.Close()
    } catch {
        Write-Log "Erro ao remover certificados expirados: $_" -tipo "ERRO"
    }
}

# Verifica e cria o diretório de logs, se necessário
if (-not (Test-Path -Path $caminhoLogs)) {
    New-Item -ItemType Directory -Path $caminhoLogs | Out-Null
    Write-Log "Diretório de logs criado: $caminhoLogs."
}

# Verifica se o usuário pertence ao grupo de segurança
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$isMember = (Get-ADUser -Identity $user.Name -Property MemberOf).MemberOf -contains (Get-ADGroup -Identity $GrupoCertificados).DistinguishedName

if ($isMember) {
    Write-Log "Usuário $($user.Name) pertence ao grupo $GrupoCertificados. Iniciando instalação de certificados."

    # Carrega o arquivo JSON
    try {
        $jsonContent = Get-Content -Path $CaminhoJson -Raw | ConvertFrom-Json
        $caminhoPadraoCertificados = $jsonContent.CaminhoPadraoCertificados
        $certificados = $jsonContent.Certificados
        Write-Log "Arquivo JSON carregado com sucesso. Caminho padrão: $caminhoPadraoCertificados."
    } catch {
        Write-Log "Erro ao carregar o arquivo JSON: $_" -tipo "ERRO"
        exit
    }

    # Instala os certificados
    Import-Certificados -usuario $user.Name -caminhoPadraoCertificados $caminhoPadraoCertificados -certificados $certificados

    # Remove certificados expirados
    Clear-CertificadosExpirados -usuario $user.Name
} else {
    Write-Log "Usuário $($user.Name) não pertence ao grupo $GrupoCertificados. Nenhum certificado será instalado." -tipo "AVISO"
}