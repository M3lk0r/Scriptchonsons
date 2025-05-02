<#
.SYNOPSIS
    Script para instalação e configuração de um controlador de domínio primário (AD DS) no Windows Server 2025 Core.
.DESCRIPTION
    Este script automatiza a instalação do AD DS em Server Core, configura um novo domínio contoso.com.br,
    define o nível funcional do domínio e floresta para Windows Server 2025 (10).
.EXAMPLE
    .\InstallADDSPrimary.ps11
.NOTES
    Autor: Eduardo Augusto Gomes (eduardo.agms@outlook.com.br)
    Data: 02/05/2025
    Versão: 1.0
        - Adicionado log da origem das atualizações (WSUS ou Microsoft Update)
        - Melhorias na exibição e organização do código
.LINK
    https://github.com/M3lk0r/Powershellson
#>

# Configurações
$DomainName = "contoso.com.br"
$NetbiosName = "CONTOSO"
$SafeModeAdministratorPassword = ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force
$DatabasePath = "C:\Windows\NTDS"
$LogPath = "C:\Windows\NTDS"
$SysvolPath = "C:\Windows\SYSVOL"
$ForestFunctionalLevel = "WinThreshold" # Windows Server 2025 (nível 10)
$DomainFunctionalLevel = "WinThreshold" # Windows Server 2025 (nível 10)

# Verificar se o script está sendo executado como administrador
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Este script precisa ser executado como Administrador!"
    Break
}

# Verificar se é Server Core
$GUIInstall = Get-WindowsFeature Server-Gui-Mgmt-Infra, Server-Gui-Shell
if ($GUIInstall.Installed -contains $true) {
    Write-Warning "Este servidor não é um Server Core!"
    Break
}

# Verificar se o servidor já é um controlador de domínio
if ((Get-WindowsFeature AD-Domain-Services).Installed) {
    $isDC = (Get-CimInstance -ClassName Win32_ComputerSystem).DomainRole
    if ($isDC -ge 4) {
        Write-Host "Este servidor já é um controlador de domínio." -ForegroundColor Yellow
        Break
    }
}

# 1. Instalar o recurso AD-Domain-Services (sem management tools)
Write-Host "Instalando o recurso AD-Domain-Services..." -ForegroundColor Cyan
Install-WindowsFeature -Name AD-Domain-Services

# 2. Importar módulo ADDSDeployment
Import-Module ADDSDeployment -Verbose

# 3. Configurar o novo domínio
Write-Host "Configurando o novo domínio $DomainName..." -ForegroundColor Cyan
try {
    Install-ADDSForest `
        -DomainName $DomainName `
        -DomainNetbiosName $NetbiosName `
        -ForestMode $ForestFunctionalLevel `
        -DomainMode $DomainFunctionalLevel `
        -SafeModeAdministratorPassword $SafeModeAdministratorPassword `
        -DatabasePath $DatabasePath `
        -LogPath $LogPath `
        -SysvolPath $SysvolPath `
        -InstallDns:$true `
        -NoRebootOnCompletion:$false `
        -Force:$true
    
    Write-Host "Instalação do AD DS concluída com sucesso!" -ForegroundColor Green
    Write-Host "O servidor será reiniciado automaticamente." -ForegroundColor Yellow
}
catch {
    Write-Host "Ocorreu um erro durante a instalação do AD DS:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Break
}

# 4. Configurações pós-instalação (após reinício manual)
Write-Host "`nApós o reinício, execute o seguinte comando para verificar o status:" -ForegroundColor Cyan
Write-Host "Get-ADDomainController -Filter * | Select-Object Name, Domain, Forest, OperationMasterRoles" -ForegroundColor White
Write-Host "`nPara gerenciar remotamente este DC, instale o RSAT em uma estação Windows:" -ForegroundColor Cyan
Write-Host "Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -ForegroundColor White